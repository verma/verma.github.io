---
title: Datascript 101 - Chapter 1
summary: Learn how to initialize Datascript and Insert and Query some records.
categories: [clojurescript, clojure]
layout: post
date: 2016-04-28 18:00:00
comments: true
---

Let's begin our journey into Datascript.  We'll start with very basic stuff.

Assuming that you have Datascript `:require`d in as `d`, initialize a database:

{{< highlight clojure >}}
(def conn (d/create-conn {})
{{< /highlight >}}

The `{}` is the schema where you define how certain attributes (think fields) behave: "Are they references?", "Are they arrays?" etc.


{{< highlight clojure >}}
(def schema {:car/maker {:db/type :db.type/ref}
             :car/colors {:db/cardinality :db.cardinality/many}}

(def conn (d/create-conn schema})
{{< /highlight >}}

Now we have a database `conn` with some schema, we're saying:

> "I will have a `:car/maker` attribute which will be a reference to some other entity (think record), so do the needful when I ask you to handle it (e.g. de-refing). Also, `:car/colors` is going to be an array."

Basically, to simplify a bit, you can think of schema as hints to Datascript to help make our lives easier.

Now, lets insert some schnitzel:

## Level 1 - Insertion

{{< highlight clojure >}}
(d/transact! conn [{:maker/name "Honda"
                    :maker/country "Japan"}]
{{< /highlight >}}

What's going on here?

 - `transact!` means we're going to transact something (insert/delete/update).
 - `conn` is our database (or database connection if you will).
 - The weird looking array is what we intend to transact.  There are several ways this can be specified as we'll learn in future lessons.  Here we are simply asking Datascript to insert these two "attributes" about "some entity" into the database.

As you can see, I didn't add any of the attributes I mentioned in my schema, you only need to define stuff that you want to specifically control.  Lets do one more.


## Level 2 - Insertion

{{< highlight clojure >}}
(d/transact! conn [{:db/id -1
                    :maker/name "BMW"
                    :maker/country "Germany"}
                   {:car/maker -1
                    :car/name "i525"
                    :car/colors ["red" "green" "blue"]}])
{{< /highlight >}}

What in the ...?

The new things here:

 - We're transacting multiple things (since the array now has two maps).
 - There's a weird `:db/id` field set to -1 in our maker insertion.
 - There's a `:car/maker` attribute set to -1 in our car insertion.
 - The `:cars/colors` attribute is an array, it will be handled correctly for us because we mentioned that in the schema, it has many wow cardinaleeteez.


You're saying:

> "Insert two things: a maker and a car made by that maker.  Give the maker an id -1 (because I am going to refer to it later), then add a car and set the car's maker ref as the maker I just inserted (identified by -1)."

I wonder if it still works if I switch the insertion order around.

The -1 is resolved to a real entity id when the transaction happens and the `:car/maker` is correctly set to it.  The -1 here is just a temporary id for us to connect stuff up as we insert it, without us having to do multiple transactions (insert maker first, get id, then insert car).

## Level 1 - Querying

Now to fetch these values out of the database:

{{< highlight clojure >}}
(d/q '[:find ?name
       :where
       [?e :maker/name "BMW"]
       [?c :car/maker ?e]
       [?c :car/name ?name]]
     @conn)
{{< /highlight >}}

This should give you `#{["i525"]}`.

That looks like an awful way to do whatever the heck its doing.  Fear not, fear is the mind-killer.

I don't want to go into how datascript stores stuff internally as datoms and all the stuff that goes on (since I don't completely understand it yet).  For now lets's keep it simple:

 - Anything that starts with `?` is a variable which will hold a value for us as we process the `:where` rules.
 - The thing after `:find` is what the query will return. In this case whatever ends up being in `?name` comes out.
 - Each `:where` rule has a specific format, for our purposes for now its: `[<entity-id> <attribute> <value>]`.
 - A variable in a rule is assigned any values that satisfies that rule. E.g. when we say `[?m :maker/name "BMW"]` the variable `?m` is at the `<entity-id>` position, so once this rule is processed, `?m` holds the entity-id for "BMW" maker.

So as we go down the rules:

 - `[?m :maker/name "BMW"]` - `?m` ends up the entity-id of the "BMW" maker.
 - `[?c :car/maker ?m]` - `?c` ends up with the entity-id of the car which has its maker as `?m` (which is "BMW").
 - `[?c :car/name ?name]` - `?name` ends up with the value of the `:car/name` attribute of the `?c` entity-id, which in this case is`"i525"`.
 - The rule processing finishes and we endup with `"i525"` in `?name` which is finally returned from the query.

You could have also done this:
{{< highlight clojure >}}
(let [car-entity (ffirst
                  (d/q '[:find ?c
                         :where
                         [?e :maker/name "BMW"]
                         [?c :car/maker ?e]]
                       @conn))]
  (:car/name (d/entity @conn car-entity)))
{{< /highlight >}}

As far as I know there are better ways of doing things that I (and may be ?you) will eventually learn about.


## Things to try

 - Insert some more cars and makers.
 - What do you get from our query when a maker has multiple cars?

## Things to think about

 - How do I get an entity-id if I want to insert a car later down the line and I've already inserted the maker? In other words, how do I insert a car which is made by "Honda"? For now may be make two queries? First to get the entity-id for "Honda" followed by a transact to do the insertion?


All of the stuff here is available [as a gist here](https://gist.github.com/verma/1be6a0ddba850eb0da437968cd5994aa){:target="_blank"}.

I will see you next time.
