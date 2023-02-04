# 2023.02.04
  - brainstorming about how statuses can work
  - what status can a goal be in?
    - archived: no longer an active goal but not completed
    - lapsed: an ephemeral goal for which the applicable time has passed
    - pending: something that you want to do eventually
    - active: something that's the active focus (given a particular time period)
    - achieved: a goal that has been accomplished
  - how should I model the idea that a goal will become pending after a certain period of time?
    - status log
      - every goal has a status log, and it's valid to future date statuses
      - the current status is the status log with all future dates truncated
      - how do we model changing a future event?
      - brainstorming
        - simple case:
          - create goal: status: pending, date: t1
          - set active: 
            - status: active, date: t2
            - status: pending, date: eod(t2)
        - marking done with future scheduled pending
          - create goal: status: pending, date: t1
          - set active: 
            - status: active, date: t2
            - status: pending, date: eod(t2)
          
          [comment]: # (this will get reverted back to pending)
          - set done: status: achieved, date: t3 

    - a pending status field
      - I don't like pending status because it feels like there are two sources of truth
      - this is also a little gross because in theory, once the time in the realworld passes the time when the pending status is supposed to start, it feels like that should be moved to the status log.
    - statuses can have an expiration date
      - create goal: status: pending, startDate: now, endDate: undefined,
      - set active: status: active, startDate: now, endDate: eod,
      - set done: status: achieved, startDate: now, endDate: undefined,
      - given a status log and a time t, a goal's current status is derived as follows:
        - iterate over the status log
        - find the status with the greatest startDate where endDate > t