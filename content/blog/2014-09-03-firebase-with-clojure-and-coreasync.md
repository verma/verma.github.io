---
layout: post
title: Firebase with Clojure & core.async
summary: A walkthrough of adding a library function to pani using core.async and multi-methods.
categories: [clojure]
comments: true
date: 2014-09-03
---

You love [Firebase](https://www.firebase.com/)? I love Firebase.

_WARNING: Fun with transducers ahead.  Note that the use of transducers could have been totally avoided, but what's the point if we're not having a little fun, right? right?_

Firebase has made client side web-apps development trivial for me. I can forget about managing my data, pushing it, sanitizing it (may be a little) and retrieving it.  These things may seem simple but having them taken care for you puts you in a different _State of Mind_ which takes that data management burden out of your thought process.

I've been working on a Firebase Clojure library called [pani](https://github.com/verma/pani) (hindi word for water).  Things are flowing (no pun intended) nicely, although Clojure support is lagging behind ClojureScript (since I tend to use the latter more).

In this post I am going to touch on one aspect of pani.  What I intend to do is write a function named `listen` which listens for events on Firebase `refs` and provides a nice way of dealing with them.  We'd be using `core.async` to deliver these events.

_I originally intended to deconstruct these delivered events using `core.match`, but it seems like `core.async` and `core.match` [don't play nicely together yet](http://dev.clojure.org/jira/browse/MATCH-96)_.

### First things first
The `listen` function will bind to Firebase events and wait for notifications.  The function will return a `core.async` `chan`.
Received _Events_ will be posted to this channel as Clojure vectors.  I will refrain from using certain functions from _pani_ itself to make things clearer (although it could have resulted in more concise code).

I am not going to show you the requires and stuff since this function will be a part of the _pani_ library and requires have already [been taken care of](https://github.com/verma/pani/blob/master/src/pani/cljs/core.cljs#L1).


### Basic Structure
I think the function should look something like:

{{<  highlight clojure  >}}
(defn listen
  "Given a Firebase root and a key (or a seq of keys) return a
   channel which will deliver events"
  [root korks]
  (let [c (chan)]
    c))
{{< /highlight >}}

The function takes a Firebase root (can be created with `pani/root` function and either a single key or a seq of keys).  We just declare a `chan` for now and return it.

Let's build on it.

### Listening for Firebase Events
Although _pani_ already has functions to listen for Firebase events, let's just re-write them here using some transducers for extra giggles.

Mostly we're just interested in three Firebase events here: `child_added`, `child_removed` and `child_changed` (let's collectively decide to not worry about `child_moved`).  For most of my use cases I've found that I never need the previous snapshot or node name (let me know if that's not the case though, or I'll sooner or later hit one).

First, let's write a little function which takes a Firebase ref and returns to us a `chan` which will have the received value posted to it (`pani/bind` does something similar) after its passed through a provided transducer.

{{<  highlight clojure  >}}
(defn- fb->chan
  "Given a firebase ref, an event and a transducer, binds and posts to returned channel"
  [fbref event td]
  (let [c (chan 1 td)]
    (.on fbref (clojure.core/name event)
         #(put! c [event %]))
    c))
{{< /highlight >}}

This function takes a Firebase ref, an event in the form of a keyword e.g. `:child_added` and a transducer.  The function pushes values as a vector into the channel.  The values look like `[event-type firebase-snapshot]`, e.g. `[:child_added #js {:firebase "stuff"}]` (that `#js` is called a _reader_, basically saying what follows needs to be interpreted as a javascript object, makes more sense when you're reading in code, hence the name).

The transducer then accepts this vector and turns it into a flattened out vector, something like `[:child_added "key name" "value"]`.  Like I said before, we can totally not use a transducer here, but we're just having a little bit of fun.

Testing this is not a trivial thing to do, so you'd have to take my word for it that it's working fine.  If you really want to test it, you can create a new ClojureScript application, refer to _pani_ and play around with it. _Hint: a good starting point for ClojureScript apps is David Nolen's [mies](https://github.com/swannodette/mies)_.

### `listen` Machinery
Once we have the `fb->chan` method, we can starting defining our `listen` function. It looks something like this for me:

{{<  highlight clojure  >}}

(defn listen
  "Listens for events on the given firebase ref"
  [root korks]
  (let [root    (walk-root root korks)
        events  [:child_added :child_removed :child_changed]
        td      (map (fn [[evt snap]]
                       [evt (.name snap) (.val snap)]))
        chans   (map (fn [event]
                       (fb->chan root event td)) events)]
    (merge chans)))

{{< /highlight >}}

The function begins by taking care of any child refs we may need to get to using `walk-root`. This function works by walking up the refs, e.g.

    "/" -> (walk-root [:hello :world]) -> "/hello/world"

Next we list the `events` we are interested in, followed by our transducer which pulls the Firebase snapshot's name and value out of the snapshot.

    [:child_added #js {:name "1" :value "sup"}] ->
        [:child_added "1" "sup"]

A simple transformation.

Finally we map over our events of interest and generate `chan`s for each one of them using the `fb->chan` method.

We finally return a merged `chan`.



### Using our new function
To begin with, let's just print what we receive.

{{<  highlight clojure  >}}
(def r (p/root "https://secret-app.firebaseio.com/"))

(let [c (p/listen r [:items])]
  (go-loop [msg (<! c)]
           (println msg)
           (recur (<! c))))
{{< /highlight >}}

We define `r` as the root of our Firebase app.  We call `listen` on it and pass it `[:items]`, since here we're interested in `/items` ref.  Any items added, removed or changed under this ref needs to be told us about.  When I run this and simulate adding and removing values, I get output like this:

    [:child_added "4" "clojure"]
    [:child_added "5" "rocks!"]
    [:child_changed "5" "rocks hard!"]
    [:child_removed "5" "rocks hard!"]

Ok, so far so good.

Let's say I want to keep track of values under my Firebase ref.  I would start with an empty map and as I receive notifications about items being added, removed or modified, I would update my map accordingly.  A nice and pretty way of doing this would be to use `clojure.match`, but we're going to stay away from it for now.  Instead we'll play a little bit with _multi-methods_.

### A whirlwind tour of Multi-methods

_Multi-methods_ you say?

A mutli-method in its gist can be thought of as a dispatch table.  Based on a certain value one of the defined methods of a multi-method will be called.  This _certain value_ is again computed by calling a function called a _dispatch function_.  All arguments passed to the multi-method are passed to this _dispatch function_. The return value of the _dispatch function_ then determines which of the functions from the _dispatch table_ needs to be called.

Let's work on a simple example:

{{<  highlight clojure  >}}
(defmulti greet :message)

(defmethod greet :bye [_]
  "Goodbye")

(defmethod greet :hello [_]
  "Hello")
{{< /highlight >}}

Here we declare a multi-method named greet, the second parameter to `defmulti` is a function.  Recall that a keyword can be called as a function on a map:

{{<  highlight clojure  >}}
(:message {:message "what"})
=> "what"
{{< /highlight >}}

So its totally fine to use a keyword as a _dispatch function_ for a multi-method as long as you're expecting a map as the only parameter.

Next, we define two cases for calling the multi-method.  This is done using the `defmethod` form.  We're essentially telling Clojure which code to call for which return value of the _dispatch function_.  When the _dispatch function_ returns `:bye` return `"Goodbye"` and when it returns `:hello`, return `"Hello"`.  Since, here, we don't really care about the arguments passed in we just use `_` in parameter list.  Read some more examples [here](http://clojuredocs.org/clojure_core/clojure.core/defmulti).  Let's test it out:

{{<  highlight clojure  >}}
(greet {:message :bye})
=> "Goodbye"

(greent {:message :hello})
=> "Hello"
{{< /highlight >}}

Mutli-methods are much broader in scope though, so if you find them interesting, read more about them.  I've found that [The Joy of Clojure](http://joyofclojure.com/) has a pretty enlightening text on these.

### Using multi-methods in our case

Before we write our mutli-method, let's try and see how we're going to use it.

{{<  highlight clojure  >}}
(let [c (p/listen r [:items])]
  (go-loop [msg (<! c)
            my-data {}]
           (let [new-data (handle-value msg my-data)]
             (println "My data is now " new-data)
             (recur (<! c) new-data))))
{{< /highlight >}}

We're running a `go-loop` here listening for messages on channel `c`.  We then pass the received message and the current value of `my-data` (our _list_ of items) to our multi-method `handle-value`.  `handle-value` is then supposed to return us the new state of our data.

We can define our multi-method like so:

{{<  highlight clojure  >}}
(defmethod handle-value #(first %1))

(defmethod handle-value :child_added [[_ k v] data]
  (assoc data k v))

(defmethod handle-value :child_removed [[_ k _] data]
  (dissoc data k))

(defmethod handle-value :child_changed [[_ k v] data]
  (assoc data k v))
{{< /highlight >}}

We know that `handle-value` gets passed two arguments.  The event type is the first element in the first argument.  We pass a `#(first %1)` function as the _dispatch function_ when defining the multi-method, which pulls the first element out of the first argument passed to the multi-method.

The `defmethod` form then defines the three situations we want to handle.  These methods don't do much other than `assoc`ing and `disassoc`ing values into passed in `data` parameter.

### Final output
When I hookup all of this machinery and run the code.  I get output like this:

    My data is now  {2 do}         ;; [:child_added "2" "do"]

    My data is now  {3 even, 2 do} ;; [:child_added "3" "even"]

    My data is now  {3 even,       ;; [:child_added "4" "eat"]
                     4 eat, 2 do}

    My data is now  {3 even,       ;; [:child_added "5" "Hello"]
                     4 eat,
                     5 Hello, 2 do}

    My data is now  {3 event,      ;; [:child_changed "3" "event"]
                     4 eat,
                     5 Hello, 2 do}

    My data is now  {3 event,      ;; [:child_removed "4" "eat"]
                     5 Hello, 2 do}
    My data is now  {3 event,      ;; [:child_removed "2" "do"]
                     5 Hello}

Things look good.

### Conclusion
Here are some of the things we discussed:

- [Firebase](https://www.firebase.com/)
- [Pani](https://github.com/verma/pani).
- [core.async](https://github.com/clojure/core.async)
- [core.match](https://github.com/clojure/core.match)
- [mies](https://github.com/swannodette/mies)
- [The Joy of Clojure](http://joyofclojure.com/)

Until next time!
