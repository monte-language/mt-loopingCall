import "unittest" =~ [=> unittest]
exports (makeLoopingCall)

# Copyright (C) 2014 Google Inc. All rights reserved.
# Copyright (C) 2015-2016 Corbin Simpson.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy
# of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

def makeLoopingCall(timer, task) as DeepFrozen:
    "Make a looping call.

     `timer` can be the unsafe object `Timer`, or any equivalent object with
     `.fromNow(duration :Double)`.

     `task` should be an object which responds to `task.run/0`."

    # How long we should wait before making our next iteration.
    var loopDuration :NullOk[Double > 0.0] := null
    # Whether we are currently supposed to recur.
    var running :Bool := false

    # Private task runner.
    def call
    def schedule():
        when (timer.fromNow(loopDuration)) ->
            call()
    bind call():
        if (running):
            task()
            schedule()

    return object loopingCall:
        "A recurring event."

        to start(duration :(Double > 0.0)) :Void:
            loopDuration := duration
            running := true
            schedule()

        to stop() :Void:
            running := false

var clockPromises := [].diverge()
object clock:
    "A strange clock only suitable for some unit tests; every tick takes an
     unbounded amount of time, and as a result, promises cannot take more than
     one tick of the clock to resolve."

    to fromNow(duration :Double):
        def [p, r] := Ref.promise()
        clockPromises.push(r)
        return p

    to tick():
        def p := promiseAllFulfilled([for r in (clockPromises)
                                      r<-resolve(null)])
        clockPromises := [].diverge()
        return p

def testLoopingCall(assert):
    # We're gonna checkpoint each modification to this box. Every assertion
    # comes after we've mutated the box.
    var box := 0
    def f():
        box += 1
    f()
    assert.equal(box, 1)
    def lc := makeLoopingCall(clock, f)
    assert.equal(box, 1)
    lc.start(1.0)
    return when (clock<-tick()) ->
        assert.equal(box, 2)
        when (clock<-tick()) ->
            assert.equal(box, 3)
            lc.stop()
            when (clock<-tick()) ->
                assert.equal(box, 3)
unittest([testLoopingCall])
