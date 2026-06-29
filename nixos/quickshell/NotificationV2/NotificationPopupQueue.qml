pragma Singleton
import Quickshell

Singleton {
  id: root

  function enqueue(queue: var, id: int): var {
    if (indexOf(queue, id) !== -1)
      return queue;
    return queue.concat([id]);
  }
  function indexOf(queue: var, id: int): int {
    return queue.indexOf(id);
  }
  function remove(queue: var, id: int): var {
    const index = indexOf(queue, id);
    if (index === -1)
      return queue;

    const nextQueue = queue.slice();
    nextQueue.splice(index, 1);
    return nextQueue;
  }
  function takeNext(queue: var, entries: var): var {
    const nextQueue = queue.slice();
    while (nextQueue.length > 0) {
      const nextId = nextQueue.shift();
      for (let index = 0; index < entries.count; index++) {
        const entry = entries.get(index);
        if (entry.id === nextId && !entry.closed)
          return {
            id: nextId,
            index: index,
            queue: nextQueue
          };
      }
    }

    return {
      id: -1,
      index: -1,
      queue: []
    };
  }
}
