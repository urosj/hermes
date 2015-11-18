require 'rubygems'
require 'pp'
require 'json'
require 'sinatra'
require 'sinatra/reloader'
require 'mongo'
require 'open-uri'

include Mongo

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



# ***************************************************
# * store changes 
# ***************************************************

get "/store/changes" do 
	content_type :json
	status 200
	body ''
end
