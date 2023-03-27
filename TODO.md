
TODO:
  - Create a settings service
  - Support rendering multiple active goals
  - implement an op rewriter
  - deeply filter the goal hierarchy
    - right now we only support removing goals from the map but we should probably filter node children as well

DONE:
  - add validation e.g. forbid cycles in the graph
  - easily add a subgoal to the active goal
  - correctly set page when paging back up through goal hierarchy
  - Implement a true wakelock
  - mark goals done
  - debug random crashes
  - implement the goal status log
  - set active goal
  - fix bugs with swiping back
  - fix syncing
  - web app