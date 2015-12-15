require 'rubygems'
require 'pp'
require 'json'
require 'sinatra'
require 'sinatra/base'
require 'sinatra/reloader'
require 'mongo'
require 'open-uri'
require 'net/http'
require 'date'
require 'ai4r'
include Ai4r::Data
include Ai4r::Clusterers

include Mongo

class MyApp < Sinatra::Base

	#@@PROD_URL = "https://api.jujucharms.com/charmstore/v4"
	@@CHARMSTORE_URL = "http://api.jujugui.org/charmstore/v4"
	@@centroids = []
	@@labels = []
	
	set :bind, '0.0.0.0'
	
	mongoClient = MongoClient.new
	db = mongoClient.db("hermes")
	@@userColl = db.collection("users")
	@@subsColl = db.collection("subscriptions")
	@@cscColl = db.collection("store_changes")
	
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
		res = @@userColl.find.to_a.to_json
		status 200
		return res
	end
	
	def createUser(userData)
		pp "creating user #{userData['_id']}"
	
		res = @@userColl.find("_id" => userData["_id"]).to_a
		if not res.empty?
			@@userColl.update({"_id" => userData["_id"]}, userData)
		else
			id = @@userColl.insert(userData)
		end
	end
	
	def userExists(username)
		res = @@userColl.find("_id" => username).to_a
		if res.empty? 
			return false
		end	
		return true
	end
	
	#curl -X PUT -H "Content-Type: application/json" -d '{"name": "John Doe", "email": "john.doe@company.com"}' http://localhost:4567/u/john-doe
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
		createUser(data)
		status 201
	end
	
	get "/u/:user" do 
		content_type :json
		res = @@userColl.find("_id" => params[:user]).to_a
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
	
		res = @@userColl.find("_id" => params[:user]).to_a
		if res.empty? 
			status 404
			body '{"error": "user not found"}'
			return
		end
	
		res = @@subsColl.find("user" => params[:user]).to_a.to_json
		status 200
		return res
	end
	
	def subscribeUser(user, subscription)
		pp "checking subscription for user #{user} to #{subscription}"
		res = @@subsColl.find("user" => user, "charm_id" => subscription).to_a
		if not res.empty?
			status 200
			return
		end
	
		pp "subscribing user #{user} to #{subscription}"
		data = {}
		data["user"] = user
		data["charm_id"] = subscription 
		id = @@subsColl.insert(data)
	end
	
	# curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "cs:wordpress"}' http://localhost:4567/u/john-doe/store/subs
	post "/u/:user/store/subs" do 
		content_type :json
		data = JSON.parse(request.body.read)
		pp data
		charm_id = data["charm_id"]
	
		res = @@userColl.find("_id" => params[:user]).to_a
		if res.empty? 
			status 404
			body '{"error": "user not found"}'
			return
		end
	
		# XXX check if the id is promulgated charm and get it's original url
	
		subscribeUser(params[:user], charm_id)	
		status 201
	end 
	
	# curl -X DELETE -H "Content-Type: application/json" -d '{"charm_id": "cs:wordpress"}' http://localhost:4567/u/john-doe/store/subs
	delete "/u/:user/store/subs" do 
		content_type :json
		data = JSON.parse(request.body.read)
		pp data
		charm_id = data["charm_id"]
	
		res = @@userColl.find("_id" => params[:user]).to_a
		if res.empty? 
			status 404
			body '{"error": "user not found"}'
			return
		end
	
		res = @@subsColl.find("user" => params[:user], "charm_id" => charm_id).to_a
		if res.empty?
			status 404
			body '{"error": "notification subscription to store not found"}'
			return
		end
	
		@@subsColl.remove( {"_id" => res[0]["_id"]} )
		status 200
	end	
	
	# ***************************************************
	# * user notifications
	# ***************************************************
	
	def notifFiler(notifications, fileters)
		res = []
		added = {}
		fileters.each {
			|filter|
			notifications.each {
				|notice|
				pp notice
				if notice["charm_id"].include?(filter["charm_id"])
					if not added.has_key?(notice["charm_id"])
						notice.delete("_id")
						res << notice
						added[notice["charm_id"]] = ""
					end
				end
			}
		}
		return res
	end
	
	get "/u/:user/store/notifications" do
		udoc = @@userColl.find("_id" => params[:user]).to_a
		if udoc.empty? 
			status 404
			body '{"error": "user not found"}'
			return
		end
		udoc = udoc[0]
	
		last_access = udoc["last_store_access"]
		last_access = Time.new(2015) if last_access.nil?
	
		docs = @@cscColl.find("publish_time" => {'$gte' => last_access.to_i}).to_a
		
		udoc["last_store_access"] = Time.now.utc
		@@userColl.update({"_id" => udoc["_id"]}, udoc)
	
		#get user subscriptions
		subs = @@subsColl.find("user" => params[:user]).to_a
		# filter the docs, so that they match the ones the user is subscribed to
		notifications = notifFiler(docs, subs)
	
		status 200
		return notifications.to_json
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
			filtered << {"charm_id" => id, "publish_time" => ptime.to_i} if ptime.to_i >= last_access.to_i
		}
		return filtered
	end
	
	get "/store/changes/aggregate" do 
		content_type :json
	
		last_time = nil
		last_doc = nil
		doc = @@cscColl.find("_id" => "last_cs_access").to_a
		if doc.empty?
			now = Time.now.utc		
			# You've got 7 days!
			history = 1
			last_time = Time.new(now.year, now.month - history, now.day, now.hour, now.min, now.sec)
		else
			pp doc
			last_doc = doc[0]
			last_time = Time.at(last_doc["time"])
		end
	
		pp last_time
		# Make a request to check all updates from last time.
		# An example of the call:
		# https://api.jujucharms.com/charmstore/v4/changes/published?start=2015-11-18
		now = Time.now.utc
		strday = "#{last_time.day}"
		strday = "0#{last_time.day}" if last_time.day < 10
		strmonth = "#{last_time.month}"
		strmonth = "0#{last_time.month}" if last_time.month < 10
		query = @@CHARMSTORE_URL + "/changes/published?start=#{last_time.year}-#{strmonth}-#{strday}"
		pp query
		contents = URI.parse(query).read
		data = JSON.parse(contents)
		pp data
	
		data = filterPublished(data, last_time)
		data.each { |entry| id = @@cscColl.insert(entry) }
		pp data.size 
	
		last_access_data = {"_id" => "last_cs_access", "time" => now.to_i}
		if last_doc.nil?
			@@cscColl.insert(last_access_data)
		else
			@@cscColl.update({"_id" => "last_cs_access"}, last_access_data)
		end
	
		status 200
		body ''
	end
	
	# ***************************************************
	# * clusters & centroids
	# ***************************************************
	
	# Create $num clusters for existing notification subscriptions
	# in a highly inefficient way :)
	get "/store/centroids/users/:num" do
		content_type :json
		# for all users
		users = @@userColl.find().to_a
		dataset = []
		users.each {
			|user|
			# create vectors of subscriptions
			usr = user["_id"]
			subs = @@subsColl.find("user" => usr).to_a
			dataset << subs.map { |x| x["charm_id"] }
		}
		pp dataset
	
		# create sparse matrix
		@@labels = []
		dataset.each {
			|set|
			set.each { |keyword| @@labels << keyword if not @@labels.include? keyword }
		}
	
		normalized = []
		dataset.each {
			|set|
			pos = 0
			data = []
			@@labels.size.times { data << 0 }
			@@labels.each {
				|label|
				data[pos] = 1 if set.include?(label)
				pos += 1
			}
			normalized << data
		}
		pp normalized
	
		data_set = DataSet.new(:data_items => normalized, :data_labels => @@labels)
		clusterer = KMeans.new.build(data_set, params[:num].to_i)
	
		clusterer.clusters.each_with_index {
			|cluster, index| 
			puts "Group #{index+1}"
			p cluster.data_items
		}
	
		@@centroids = clusterer.centroids
		@@centroids.each_with_index {
			|centroid, index| 
			puts "Group #{index+1}"
			p centroid
		}
	
		pp "Number of clusters: #{@@centroids.size}"
		# then use those to cluster them
		status 200
		return @@centroids.to_json
	end
	
	get "/store/centroids/published" do
		content_type :json
	
		cache = {}

		entries = @@cscColl.find().to_a
		entries.each {
			|entry|
			str = entry["charm_id"].to_s
			str.gsub!("cs:", "")
			next if str.nil?
			user = ""
			charm = ""
			split = str.split('-')[0...-1].join('-').split('/')
			next if split.nil? or split.size < 2
			#cache_key = split[0]+"/"+split[-1]
			#if not cache.has_key?(cache_key)
			#	pp "cache miss for #{cache_key}"
				begin
					query = @@CHARMSTORE_URL + "/#{str}/meta/extra-info/bzr-digest"
		    		contents = URI.parse(query).read
		    		#data = JSON.parse(contents)
					#user = data["User"]
					contents.gsub!("\"", "")
					user = contents.split('@')[0]
				rescue Exception => err
		    		p err
				end	
				next if user.include?("_bot-")
				charm = ""
				begin
					query = @@CHARMSTORE_URL + "/#{str}/meta/id-name"
		    		contents = URI.parse(query).read
		    		data = JSON.parse(contents)
					charm = data["Name"]
				rescue Exception => err
		    		p err
				end	
				#cache[cache_key] = [user, charm]
				#user = cache[cache_key][0]
				#charm = cache[cache_key][1]
		
				# check if user exists
				if not userExists(user) 
					# if it doesn't, create new user
					data = {}
					data["_id"] = user
					data["email"] = "a@a.com"
					data["name"] = user
		
					createUser(data)
				end
				# register new subscription to user
				subscribeUser(user, charm)
			#end
		}
	
		status 200
	end
	
	# ***************************************************
	# * recommendations
	# ***************************************************
	
	# curl -X POST -H "Content-Type: application/json" -d '{"charm_ids": ["keystone"]}' http://localhost:4567/store/recommend
	post "/store/recommend" do
		content_type :json
	
		data = JSON.parse(request.body.read)
		ids = data["charm_ids"]
		pp ids
		normalized = []
		#pp @@labels
		@@labels.each { |label| ids.include?(label) ? normalized << 1 : normalized << 0 }
		#pp normalized
	
		# Calculate distance from centroids
		min_dist = nil
		closest_cenroid = nil
		@@centroids.each {
			|centroid|
			dist = KMeans.new.distance(centroid, normalized)
			pp "dist is #{dist}"
			if min_dist.nil?
				min_dist = dist
				closest_cenroid = centroid
			end
			if dist < min_dist 
				min_dist = dist
				closest_cenroid = centroid
			end
		}

		pp closest_cenroid
		result = Hash[@@labels.zip(closest_cenroid)]
		result = result.sort_by {|_key, value| value}.reverse
		#normalize
		maxval = 1
		maxval = 1 / result[0][1] if result[0][1] > 0
		result = result.select { |x| x[1]*maxval > 0.33 && !ids.include?(x[0]) }
		pp result
	
		status 200
		return result.to_json
	end

	# curl -X POST -H "Content-Type: application/json" -d '{"charm_ids": ["keystone"]}' http://localhost:4567/store/recommend/filter
	post "/store/recommend/filter" do
		content_type :json

		status 200
	end

	run!
end	

