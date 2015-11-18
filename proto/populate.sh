#/bin/bash

# populate users
curl -X PUT -H "Content-Type: application/json" -d '{"name": "John Doe", "email": "john.doe@company.com"}' http://localhost:4567/u/john-doe
curl -X PUT -H "Content-Type: application/json" -d '{"name": "John Dow", "email": "john.dow@company.com"}' http://localhost:4567/u/john-dow
curl -X PUT -H "Content-Type: application/json" -d '{"name": "John Dough", "email": "john.dough@company.com"}' http://localhost:4567/u/john-dough

curl -X PUT -H "Content-Type: application/json" -d '{"name": "John Dog", "email": "john.doh@company.com"}' http://localhost:4567/u/john-dog
curl -X PUT -H "Content-Type: application/json" -d '{"name": "John Doug", "email": "john.doug@company.com"}' http://localhost:4567/u/john-doug

# populate subscriptions
curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "bigdata"}' http://localhost:4567/u/john-doe/store/subs
curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "hadoop"}' http://localhost:4567/u/john-doe/store/subs
curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "analytics"}' http://localhost:4567/u/john-doe/store/subs

curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "hadoop"}' http://localhost:4567/u/john-dow/store/subs
curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "spark"}' http://localhost:4567/u/john-dow/store/subs
curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "pig"}' http://localhost:4567/u/john-dow/store/subs
curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "analytics"}' http://localhost:4567/u/john-dow/store/subs

curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "bigdata"}' http://localhost:4567/u/john-dough/store/subs
curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "spark"}' http://localhost:4567/u/john-dough/store/subs


curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "openstack"}' http://localhost:4567/u/john-dog/store/subs
curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "keystone"}' http://localhost:4567/u/john-dog/store/subs
curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "glance"}' http://localhost:4567/u/john-dog/store/subs

curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "glance"}' http://localhost:4567/u/john-doug/store/subs
curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "keystone"}' http://localhost:4567/u/john-doug/store/subs
curl -X POST -H "Content-Type: application/json" -d '{"charm_id": "cinder"}' http://localhost:4567/u/john-doug/store/subs

