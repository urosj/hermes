require 'rubygems'
require 'pp'
require 'json'
require 'sinatra'
require 'sinatra/reloader'
require 'mongo'
require 'open-uri'
require 'date'

include Mongo

@@CHARMSTORE_URL = "http://api.jujugui.org/charmstore/v4"

set :bind, '0.0.0.0'

mongoClient = MongoClient.new
db = mongoClient.db("hermes")
userColl = db.collection("users")
subsColl = db.collection("subscriptions")
cscColl = db.collection("store_changes")

# ***************************************************
# * Prototype for Hermes service. Note that data 
# * endpoints are not protected! 
# ***************************************************

get '/about' do 
	content_type 'text/html'
	s = "<html><title>Hermes</title>"
	s += "<body><h1>Hermes prototype</h1>"
	s += "</body></html>"
end

# ***************************************************
# * user handling 
# ***************************************************

get "/u" do 
	content_type :json
	res = userColl.find.to_a.to_json
	status 200
	return res
end

=begin
curl -X PUT -H "Content-Type: application/json" -d '{"name": "John Doe", "email": "john.doe@company.com"}' http://localhost:4567/u/john-doe
=end
put "/u/:user" do 
	pp params[:user]

	content_type :json
	data = JSON.parse(request.body.read)
	pp data
	
	name = data["name"]
	email = data["email"]
	if name.nil? or email.nil? or name.empty? or email.empty?
		status 400
		body '{"error": "missing data, name and email required"}'
		return
	end

	data["_id"] = params[:user]
	res = userColl.find("_id" => params[:user]).to_a
	if not res.empty?
		userColl.update({"_id" => params[:user]}, data)
	else
		id = userColl.insert(data)
	end

	status 201
end

get "/u/:user" do 
	content_type :json
	res = userColl.find("_id" => params[:user]).to_a
	if res.empty? 
		status 404
		body '{"error": "user not found"}'
		return
	end
	status 200
	return res.to_json
end

# ***************************************************
# * user store subscriptions handling 
# ***************************************************


get "/u/:user/store/subs" do 
	content_type :json

	res = userColl.find("_id" => params[:user]).to_a
	if res.empty? 
		status 404
		body '{"error": "user not found"}'
		return
	end

	res = subsColl.find("user" => params[:user]).to_a.to_json
	status 200
	return res
end

# curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "cs:wordpress"}' http://localhost:4567/u/john-doe/store/subs
post "/u/:user/store/subs" do 
	content_type :json
	data = JSON.parse(request.body.read)
	pp data
	charm_id = data["charm_id"]

	res = userColl.find("_id" => params[:user]).to_a
	if res.empty? 
		status 404
		body '{"error": "user not found"}'
		return
	end

	# XXX check if the id is promulgated charm and get it's original url

	res = subsColl.find("user" => params[:user], "charm_id" => charm_id).to_a
	if not res.empty?
		status 200
		return
	end

	data = {}
	data["user"] = params[:user]
	data["charm_id"] = charm_id 
	id = subsColl.insert(data)
	status 201
end 

# curl -X DELETE -H "Content-Type: application/json" -d '{"charm_id": "cs:wordpress"}' http://localhost:4567/u/john-doe/store/subs
delete "/u/:user/store/subs" do 
	content_type :json
	data = JSON.parse(request.body.read)
	pp data
	charm_id = data["charm_id"]

	res = userColl.find("_id" => params[:user]).to_a
	if res.empty? 
		status 404
		body '{"error": "user not found"}'
		return
	end

	res = subsColl.find("user" => params[:user], "charm_id" => charm_id).to_a
	if res.empty?
		status 404
		body '{"error": "notification subscription to store not found"}'
		return
	end

	subsColl.remove( {"_id" => res[0]["_id"]} )
	status 200
end	

# ***************************************************
# * user notifications
# ***************************************************

get "/u/:user/store/notifications" do
	udoc = userColl.find("_id" => params[:user]).to_a
	if udoc.empty? 
		status 404
		body '{"error": "user not found"}'
		return
	end
end

# ***************************************************
# * store changes 
# ***************************************************

def filterPublished(data, last_access)
	last = last_access.to_i
	filtered = []
	data.each {
		|ht|
		id = ht["Id"]
		stime = ht["PublishTime"]
		ptime = Time.parse(stime)
		filtered << {"charm_id" => id, "publish_time" => ptime} if ptime.to_i >= last
	}
	return filtered
end

get "/store/changes/aggregate" do 
	content_type :json

	last_time = nil
	last_doc = nil
	doc = cscColl.find("_id" => "last_cs_access").to_a
	if doc.empty?
		now = Time.now.utc		
		# You've got 7 days!
		history = 1
		last_time = Time.new(now.year, now.month, now.day - history, now.hour, now.min, now.sec)
	else
		pp doc
		last_doc = doc[0]
		last_time = last_doc["time"]
	end

	pp last_time
	# Make a request to check all updates from last time.
	# An example of the call:
	# https://api.jujucharms.com/charmstore/v4/changes/published?start=2015-11-18
	now = Time.now.utc
	query = @@CHARMSTORE_URL + "/changes/published?start=#{last_time.year}-#{last_time.month}-#{last_time.day}"
	pp query
	contents = URI.parse(query).read
	data = JSON.parse(contents)
	pp data

	data = filterPublished(data, last_time)
	data.each { |entry| id = cscColl.insert(entry) }
	pp data.size 

	last_access_data = {"_id" => "last_cs_access", "time" => now}
	if last_doc.nil?
		cscColl.insert(last_access_data)
	else
		cscColl.update({"_id" => "last_cs_access"}, last_access_data)
	end

	status 200
	body ''
end

