---
title: Datascript 101 - Chapter 2
summary: Learn how to setup uniqueness and identity.
categories: [clojurescript, clojure]
layout: post
date: 2016-05-06
comments: true
---

This is part 2 of 3 part series on Datascript.  I suggest that you skim over [Part 1]({{<  ref "2016-04-28-datascript101-chapter1-initializing-inserting-and-querying-records" >}}) before reading this.

Random quote from Dune:

> “It is so shocking to find out how many people do not believe that they can learn, and how many more believe learning to be difficult.” ― Frank Herbert, Dune

We will try to setup some identities and make our lives easier a bit.

Lets do this!

{{< highlight clojure >}}
(def schema {:car/model {:db/unique :db.unique/identity}
             :car/maker {:db/type :db.type/ref}
             :car/colors {:db/cardinality :db.cardinality/many}}
{{< /highlight >}}

See that `:car/model` definition.  You're saying:

> "Hey this :car/model field is going to be unique and will be used to identify this entity (a car in this case)."

These entity "identifiers" can be your domain specific things (so you don't have to always rely on Datascript's ID stuff), things like order numbers, email addresses etc.

Lets define an "identifier" (or an identity) for our makers as well.

{{< highlight clojure >}}
(def schema {:maker/email {:db/unique :db.unique/identity}

             :car/model {:db/unique :db.unique/identity}
             :car/maker {:db/type :db.type/ref}
             :car/colors {:db/cardinality :db.cardinality/many}}

(def conn (d/create-conn schema})
{{< /highlight >}}

We'll be identifying our makers by their email addresses.

## Level 3 - Insertion

Lets insert a new maker and a car along with it.

{{< highlight clojure >}}
(d/transact! conn [{:maker/email "ceo@bmw.com"
                    :maker/name "BMW"}
                   {:car/model "E39530i"
                    :car/maker [:maker/email "ceo@bmw.com"]
                    :car/name "2003 530i"}])
{{< /highlight >}}

Some things to notice:

 - We're inserting a maker and a car together (like we did in our last chapter).
 - We're not using `-1` to explicitly assign a temporary ID to our maker to be able to refer to it when adding our car (like we did in our last chapter).
 - We're using something called a "plz lookup a ref for me" (also know as "lookup-refs") to identify our maker and then refer to it, that `[:maker/email "ceo@bmw.com"]` is a lookup ref. So we don't have to deal with `-1` etc. or Datascript generated entity IDS.

Note that Datascript will still generate a `:db/id` for us behind the scenes, but for all intents and purposes for now, you can use lookup-refs instead of entities wherever they're needed.

All of this is fine and dandy, but what can I do with it other than easy insertions?

## Level 2 - Querying

Concise entity lookups

{{< highlight clojure >}}
(d/entity @conn [:car/model "E39530i"])
=> {:db/id 2}

(d/entity @conn [:maker/email "ceo@bmw.com"])
=> {:db/id 1}

{{< /highlight >}}

In our last chapter, we had to write a pretty elaborate query to get the entity ID which we could pass to `d/entity`.  Now we can use a lookup-ref to fetch the same thing.

Note that, `d/entity` returns a "lazy" entity.  When you fetch a certain attribute out of it, it will be resolved for you.

{{< highlight clojure >}}
(:maker/name (d/entity @conn [:maker/email "ceo@bmw.com"]))
=> "BMW"
{{< /highlight >}}

## Level 4 - Insertion

We want to insert a new car now, and need the ref of our maker to insert it.  Because of lookup refs we don't have explictely query entity IDs:

{{< highlight clojure >}}
(d/transact! conn [{:car/model "E39520i"
                    :car/maker [:maker/email "ceo@bmw.com"]
                    :car/name "2003 520i"}])
{{< /highlight >}}

WIN! We just used a lookup-ref to specify the maker!


## Level 3 - Querying

Can we use these lookup-refs when querying stuff? Lets find all cars made by BWM.

{{< highlight clojure >}}

(d/q '[:find [?name ...]
       :where
       [?c :car/maker [:maker/email "ceo@bmw.com"]]
       [?c :car/name ?name]]
     @conn)
=> ["2003 530i" "2003 520i"]
{{< /highlight >}}

Yay!  See that `[?name ...]` unholy-ness right after `:find`?  I will tackle that in my next chapter!

## Level 5 - Insertion

ACHIVEMENT UNLOCKED! You're still here!

What if BMW CEO decides that the name "BWM" needs to be changed to "BWM Motors".  How can we go and update the name? Lookup-refs make your life easier here as well:

{{< highlight clojure >}}
(d/transact! conn [{:maker/email "ceo@bmw.com"
                    :maker/name "BMW Motors"])
{{< /highlight >}}

You're basically re-inserting a maker with a new name but the email is the same as the one we already have, it will be taken care of for you.

{{< highlight clojure >}}
(:maker/name (d/entity @conn [:maker/email "ceo@bmw.com"]))
=> "BMW Motors"
{{< /highlight >}}

## Takeaways

Here are some things to take away from this chapter:

 - Lookup-refs are interchangeable with entity IDs almost everywhere, Datascript will complain when they're not, so go ahead and use them liberally.
 - Use identity and uniqueness to model your domain specific "identifiers".


## Things to try

  - Insert some more makers and cars.
  - Try adding some more attributes and identities to the schema and try and use them.

All of the stuff here is available [as a gist here](https://gist.github.com/verma/754521e85d9ddbc6554df13b82e3e255){:target="_blank"}.


I will see you next time!

