---
layout: post
title: JSON Web Services with Clojure
summary: Go through a quick exercise to make writing JSON Web Services a breeze, a fun filled breeze.
comments: true
categories: [clojure]
date: 2014-08-19
---

Less reading more coding.

The goal here is to setup Compojure in such a way that we just deal in Clojure maps when writing our Web Service.

All code for this exercise is available [here](https://github.com/verma/json-webservice-test).

### Pre-reqs
This exersise assumes some knowledge of Clojure and Compojure, here are some nice starting points:

- [Creating and managing projects with lein](https://github.com/technomancy/leiningen/blob/stable/doc/TUTORIAL.md).
- [Compojure](https://github.com/weavejester/compojure).
- [Routes in Compojure](https://github.com/weavejester/compojure/wiki/Routes-In-Detail).
- [Ring](https://github.com/ring-clojure/ring)

### Setup a project

    lein new compojure api-test

This sets up `api-test` with a basic [Compojure](https://github.com/weavejester/compojure) template.

### Add some deps

{{<  highlight clojure  >}}
;; project.clj
;; ...
:dependencies [[org.clojure/clojure "1.6.0"]
               [ring/ring-json "0.3.1"]
               [compojure "1.1.8"]]                 

{{< /highlight >}}

Run the server (it will update itself whenever you make a code change, you don't have to keep restarting the server, unless you add more dependencies)

    lein ring server

### Add JSON middleware

Change your app definition to include the required middleware (make sure you require the middleware as well):

{{<  highlight clojure  >}}
;; src/api_test/handler.clj

(ns api-test.handler
  (:require [compojure.core :refer :all]
            [compojure.handler :as handler]
            [ring.middleware.json :as middleware]
            [compojure.route :as route]))

;; ...

(def app
  (-> (handler/site app-routes)
      (middleware/wrap-json-body {:keywords? true})
      middleware/wrap-json-response))

{{< /highlight >}}

The `{:keywords? true}` above makes sure that when my body is parsed, I get my keys as keywords and not as strings.

### Write a handler

You get two things out of doing all this so far:

1. All JSON request bodies are parsed into nice looking maps for your convenience.
2. Response bodies can now be maps as well, which will be converted into JSON before they're put on the wire.

Lets write the handler (just look at the `POST "/"` stuff, [read more](http://weavejester.github.io/compojure/compojure.route.html) about Compojure to learn what other things do):

{{<  highlight clojure  >}}
(defroutes app-routes
  (POST "/" request
    (let [name (or (get-in request [:params :name])
                   (get-in request [:body :name])
                   "John Doe")]
      {:status 200
       :body {:name name
       :desc (str "The name you sent to me was " name)}}))
  (route/resources "/")
  (route/not-found "Not Found"))

{{< /highlight >}}

First it figures the name of the sender, it could be either in `params`, the `body` or defaults to `"John Doe"` (see how nicely you can query the body here for things).


{{<  highlight clojure  >}}
;; ...
{:status 200
 :body {:name name
        :desc (str "The name you sent to me was " name)}}

{{< /highlight >}}

This is how you generate your body now, just a simple clojure map.

### Test it

Lets check it out in console:

    $ curl -X POST http://localhost:3000/ \
            --data '{"name":"verma"}' --header "Content-type:application/json"
    {"name":"verma","desc":"The name you sent to me was verma"}

    $ curl -X POST --data 'name=verma' http://localhost:3000/
    {"name":"verma","desc":"The name you sent to me was verma"}

    $ curl -X POST  http://localhost:3000/
    {"name":"John Doe","desc":"The name you sent to me was John Doe"}

### Credits

Thanks to `jakecraige` and `milos_cohagen` for their corrections, comments and suggestions on `#clojure` @ freenode.  Come join the fun!

Until next time!
