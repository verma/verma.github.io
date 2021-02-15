---
layout: post
title: Writing Slack integrations in Clojure
comments: true
summary: Slack integrations are awesome, in this series we'll develop an integration which will help us do something useful.
categories: [clojure]
redirect_from: "/2014/08/21/writing-hooks-for-slack-in-clojure/"
---

I've been playing a lot with Slack lately.  At [Mazira](https://www.mazira.com/), it has become an integral part of our workflow, and it hasn't been very long since we started using it.  Some things are love at first sight and I feel Slack is one of them.

### What are we doing?
This exercise is not intended to be a tutorial on writing Slack Integrations, it's more like doing fun stuff in Clojure.

Source code is available [here](https://github.com/verma/slack-weather).

We'll setup a basic project in Clojure and build a Slack integration.  We'd be querying [OpenWeatherMap](http://openweathermap.org/) for weather information for the given zip code. I guess it's nice to know how it is outside when you spend your entire day inside, on a computer, writing Clojure.

OpenWeatherMap provides weather over a freely accessible API which returns results in JSON.  [Try this](http://api.openweathermap.org/data/2.5/find?q=95136,USA&units=imperial).

On the Slack side of things, you need to setup an _Incoming Webhook_.  Details for doing that can be found [here](https://my.slack.com/services/new/incoming-webhook).  You should eventually end up with a URL to which you can post well-defined data.

### Setting up the projects
Let's begin by starting a new project.

    lein new compojure slack-weather

This will create a new project for you named `slack-weather` using the `compojure` template.

We're going to import some dependencies. I like to use [clj-http](https://github.com/dakrone/clj-http) for making web-requests, [data.json](https://github.com/clojure/data.json) for manipulating JSON and [core.async](https://github.com/clojure/core.async) for general awesomeness (for the `thread` function actually).  Let's add these deps to the `project.clj` file.  After you're done making changes it should look something like:

{{<  highlight clojure  >}}

(defproject slack-weather "0.1.0-SNAPSHOT"
  :description "FIXME: write description"
  :url "http://example.com/FIXME"
  :dependencies [[org.clojure/clojure "1.6.0"]
                 [compojure "1.1.8"]
                 [org.clojure/data.json "0.2.5"]
                 [org.clojure/core.async "0.1.319.0-6b1aca-alpha"]
                 [clj-http "1.0.0"]]
  :plugins [[lein-ring "0.8.11"]]
  :ring {:handler slack-weather.handler/app}
  :profiles
  {:dev {:dependencies [[javax.servlet/servlet-api "2.5"]
                        [ring-mock "0.1.5"]]}})
{{< /highlight >}}

I use [vim-fireplace](https://github.com/tpope/vim-fireplace) for Clojure development, so what you do here may vary.  Let's open a terminal window, navigate to the project directory and start a REPL.

    lein repl

When the REPL is running, you can go back to your VIM and `:Connect` to it.  Please refer to vim-fireplace instructions on how to go about it.

### Moving forward

We'll start with some exploratory stuff and then build upon it.  Open the `src/slack_weather/handler.clj` file in VIM.  Go to the namespace definition section to require the things we need.  Since we're not going jump ahead of ourselves, let's just include `clj-http` for now and go from there.  Your namespace definition should look something like this once you're done:

{{<  highlight clojure  >}}
(ns slack-weather.handler
  (:require [compojure.core :refer :all]
            [compojure.handler :as handler]
            [compojure.route :as route]
            [clj-http.client :as client]))
{{< /highlight >}}

Place your cursor on the outermost form (where it says `ns`) and hit `cpp` to get the expression evaluated.  If all went well, you should see a `nil` print out in VIM's command buffer.

At this point we have the `clj-http.client` library(among other things) included.  Let's play with it.

Hit `cqc` and a _quasi-REPL_ window will open.  Type in the following and hit enter:

{{<  highlight clojure  >}}
(client/get "http://www.google.com")
{{< /highlight >}}

Something should happen. Page full of content. Hit q to get out of it.  At this point we're ready to post messages to slack, but first let's assign the Slack URL to something more convenient:

{{<  highlight clojure  >}}
(def hook-url "https://myslack.slack.com/...") ; use your real URL
{{< /highlight >}}

Now let's write a function which takes a URL and a map (which will hold our content) and posts it to the given URL.  Since we need to emit JSON (which is what Slack accepts), make sure you require `[clojure.data.json :as json]` and re-eval your namespace definition (`cpp` in fireplace).

{{<  highlight clojure  >}}
(defn post-to-slack [url msg]
  (client/post url {:body (json/write-str msg)
                    :content-type :json}))
{{< /highlight >}}

Let's eval (`cpp` in fireplace) this expression, along with the `hook-url` expression and open the _quasi-REPL_ (`cqc` in fireplace).  Try calling this function a few times:

{{<  highlight clojure  >}}
(post-to-slack hook-url {:text "Test message"})
(post-to-slack hook-url {:text "Another message"
                         :username "SASSY BOT"
                         :icon_emoji ":feelsgood:"}) ;; more exciting
{{< /highlight >}}

Seems to be working alright.  Let's add the `username` and `icon_emoji` fields as defaults unless explicitly overridden by the caller.

{{<  highlight clojure  >}}
(defn post-to-slack [url msg]
  (let [m (merge {:username "SASSY BOT"
                  :icon_emoji ":feelsgood:"} msg)]
    (client/post url {:body (json/write-str m)
                      :content-type :json})))
{{< /highlight >}}

This method now provides some overridable defaults:
{{<  highlight clojure  >}}
(post-to-slack hook-url {:text "Should have :feelsgood: icon"})
(post-to-slack hook-url {:text "Should have :sunglasses: icon"
                         :icon_emoji ":sunglasses:"})
{{< /highlight >}}

Seems like we've got posting to Slack down, so it's time to move on to getting some real data.

### Getting Real Data

Let's now build a suite of functions which make its easier to deal with OpenWeatherMap data.  First let's just try to query the weather information and see what we get (hint: use `cqc` in fireplace):

{{<  highlight clojure  >}}
(client/get "http://api.openweathermap.org/data/2.5/find?q=95136,USA&units=imperial")
{{< /highlight >}}

Seems like we got something back.  The returned content is still a string, let's start wrapping this in a function:

{{<  highlight clojure  >}}
(defn weather-for-zip [zip]
  (let [content (-> (str "http://api.openweathermap.org/data/2.5/find?q="
                         zip
                         ",USA&units=imperial")
                    client/get
                    :body
                    json/read-str)]
    content))
{{< /highlight >}}

Our data of interest is laid out in objects inside objects. e.g.

    name       -> list[0].name
    temp       -> list[0].main.temp
    humidity   -> list[0].main.humidity
    temp-min   -> list[0].main.temp_min
    temp-max   -> list[0].main.temp_max
    conditions -> list[0].weather[0].main

Although we can manually pull these values out, let's go a step further and brew up a function that does it for us.

{{<  highlight clojure  >}}
(defn pull-values [m val-map]
  (into {} (for [[k v] val-map]
             [k (get-in m (if (sequential? v) v [v]))])))
{{< /highlight >}}

This function takes a map `m` to pull values out of and another map `val-map` which tells it which values to pull and what to assign them to.

We can use this function to pull our items of interest out of the OpenWeatherMap data.

{{<  highlight clojure  >}}
(defn weather-for-zip [zip]
  (-> (str "http://api.openweathermap.org/data/2.5/find?q="
           zip
           ",USA&units=imperial")
      client/get
      :body
      json/read-str
      (pull-values {:name ["list" 0 "name"]
                    :temp ["list" 0 "main" "temp"]
                    :humidity ["list" 0 "main" "humidity"]
                    :temp-min ["list" 0 "main" "temp_min"]
                    :temp-max ["list" 0 "main" "temp_max"]
                    :conditions ["list" 0 "weather" 0 "main"]})))
{{< /highlight >}}

We've gotten rid of the `content` def along with adding the `pull-value` call.  Try this out in REPL (`cpp` and `cqc` in fireplace) and see if we're getting awesome results.  Feel free to pull out more information like wind speed, direction etc.

### Formatting Results
We now need to convert this hash-map of weather data into a nicer looking string representation.  Let's write a function which does that:

{{<  highlight clojure  >}}
(defn weather-to-str [w]
  (str (:name w) " " (:temp w) "F " (:conditions w)
       ", Min: " (:temp-min w) "F, Max: " (:temp-max w) "F"
       ", Humidity: " (:humidity w))
{{< /highlight >}}

This should give you a reasonable-looking weather string.


### Putting things together
At this point we have all the pieces to post weather information to slack.

{{<  highlight clojure  >}}
(defn weather-to-slack [zip]
  (let [weather (-> zip
                    weather-for-zip
                    weather-to-str)]
    (post-to-slack hook-url {:text weather
                             :icon_emoji ":cloud:"})))

{{< /highlight >}}

This function puts all the pieces together, taking a zip code and pushing the relevant weather information to the `hook-url` Slack URL.

### Accepting Commands
So far we've just been playing with the REPL, building our functions to fetch weather information and pushing it to Slack.  We did start the project using a Compojure template, but we haven't used any web server functionality.

Slack Commands work by pushing information to a URL you provide.  Try creating a Slack Command integration and it will give you details about what parameters Slack is going to send to you.  Basically, whenever you type in `/command-name` in one of the channels, the Slack command gets triggered.

Your request handler is then supposed to return a string representing the result of the command.  I like to send a progress message back, something like "Please wait..." and then do an actual post to the channel (using all of the stuff we've already built) when I have the data available (weather information in our case).

Slack also sends you a token, which you should validate before accepting and processing a request.

At this time, I would open another terminal window, navigate to my project directory and run the ring server.

    lein ring server

This will serve the web service on port 3000 by default and will auto-update itself every time you modify the project source files.

Let's first set the basic Compojure handler to accept incoming commands.  My `defroutes` definition now looks like this:

{{<  highlight clojure  >}}
(defroutes app-routes
  (POST "/slack" request
        {:status 200
         :content-type "text/plain"
         :body "Getting weather information, please wait."})
  (route/resources "/")
  (route/not-found "Not Found"))
{{< /highlight >}}

Now setup a Slack Command Integration which will give the token information.  When setting up the integration, Slack is going to ask you for the URL where it should post the command information.  Since we're developing our stuff locally and don't really have a publicly accessible end-point, I usually run a tunneling software like `ngrok` to expose my services to the interwebs. `ngrok` will give you a URL where your service is reachable.  Copy it and give it to Slack.

You should now be able to go to a channel and just type in `/weather`.  You should see our response string popup.

The parameters will arrive under `(:params request)`. `:command` will contain the actual command (you can have multiple commands go to a single server). `:text` will contain any additional parameters sent to us .e.g the zip code.  Let's do some error checking and see how things go.

{{<  highlight clojure  >}}
(defn check-zip [zip]
  (re-matches #"^\d{5}$" (clojure.string/trim zip)))

(defroutes app-routes
  (POST "/slack" {:keys [params] :as request}
        (if (and (= "/weather" (:command params))
                 (= auth-token (:token params))
                 (check-zip (:text params)))
          {:status 200
           :content-type "text/plain"
           :body "Getting weather information, please wait."}
          {:status 400
           :content-type "text/plain"
           :body "You need to provide a valid zip code"}))
  (route/resources "/")
  (route/not-found "Not Found"))
{{< /highlight >}}

We first write a function `check-zip` which makes sure that provided zip codes are 5 digit numbers and spaces on either side of input are trimmed.

For the request to be valid, the `:command` field needs to say `"/command"`, the auth token needs to match the token we were given when we created the command integration and finally the zip code that arrived in `:text` needs to be valid.  Play around with this either in your REPL or from the Slack channel window.  I did reasonable amount of testing (2 mins) to make sure things were working.

Right now we just have the request returning a status message back to Slack.  We're not really doing any actual work.  We should now hook in our weather query machinery from before into this request handler, something like:

{{<  highlight clojure  >}}
(defroutes app-routes
  (POST "/slack" {:keys [params] :as request}
        (if (and (= "/weather" (:command params))
                 (= auth-token (:token params))
                 (check-zip (:text params)))
          (do
            (thread (weather-to-slack (clojure.string/trim (:text params))))
            {:status 200
             :content-type "text/plain"
             :body "Getting weather information, please wait."})
          {:status 400
           :content-type "text/plain"
           :body "You need to provide a valid zip code"}))
  (route/resources "/")
  (route/not-found "Not Found"))

{{< /highlight >}}

Remember to refer to `thread` call by requiring `[clojure.core.async :refer [thread]]`.  On a valid request we run our weather machinery in a separate thread, which eventually gets the data and posts it to the configured channel.

### Conclusion
Hopefully it was a fun ride getting this to work.  Some of the things referred to in this post:

- [Slack](https://slack.com/)
- [Clojure](http://clojure.org/)
- [Compojure](https://github.com/weavejester/compojure)
- [OpenWeatherMap](http://openweathermap.org/)
- [vim-fireplace](https://github.com/tpope/vim-fireplace)
- [ngrok](https://ngrok.com/)

If you're feeling particularly generous today, follow me on [Twitter](https://twitter.com/udaykverma).

### Credits
Thanks to Liz Silich for proof-reading this post.



