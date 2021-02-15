---
layout: post
title: Playing with Dates
summary: Clojure's composability to build dates using clj-time
comments: true
categories: [clojure]
date: 2014-08-20
---

Build small self contained units of code (possibly pure) and combine them to make them do more complex stuff.

It fit nicely into what I was doing when playing with dates and generating histograms.

I had to get to a certain date in the past to start building my histogram.  Libraries like moment.js make it pretty trivial:

{{<  highlight javascript  >}}
moment().subtract('2', 'months');
moment().subtract(moment.duration(2, 'months'))
{{< /highlight >}}
   
This will give you a date 2 months ago from now.

Although this works fine and I am reasonably happy with it, I find it somewhat limiting.  Using Clojure (and [clj-time] specifically), you could do this something like:

{{<  highlight clojure  >}}
(-> 2 months ago)
{{< /highlight >}}
    
which is equivalent to saying

{{<  highlight clojure  >}}
(ago (months 2))
{{< /highlight >}}
    
Other than being easier on eyes (matter of opinion I've been told), we have Clojure's composability at work here.  `ago` and `months` are two functions, and not literals which have a set meaning.  You can write your own functions to further extend this.

Lets say I want to clamp the time to midnight (which basically means setting hours, minutes and seconds to 0).  You could write a function that just does that:

{{<  highlight clojure  >}}
(defn at-midnight [t]
  (date-midnight 
    (year t)
    (month t)
    (day t))))
{{< /highlight >}}

Basically, just pick the year, month and day part out of the supplied time value and construct a new `date-midnight` instance out of it.  I can then use this function as a part of my compositional chain:

{{<  highlight clojure  >}}
(-> 2 months ago at-midnight)
{{< /highlight >}}
    
which now gives you time at midnight, 2 months ago.

#### References

1. [clj-time] - A date and time library for Clojure, wrapping the Joda Time library.
2. [cljs-time] - A clj-time inspired date library for clojurescript.

[clj-time]: https://github.com/clj-time/clj-time "clj-time"
[cljs-time]: https://github.com/andrewmcveigh/cljs-time "cljs-time"
