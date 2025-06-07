import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;

class MessageQueue {
  private final Queue<BaseMessage> queue = new ConcurrentLinkedQueue<BaseMessage>();

  /**
   * Adds a message to the end of the queue.
   * This operation is thread-safe.
   * @param message The message to enqueue.
   */
  public void enqueue(BaseMessage message) {
    if (message == null) {
      // Optional: Add a log or throw an IllegalArgumentException if null messages are not allowed.
      // For now, ConcurrentLinkedQueue allows null elements if not specified otherwise,
      // but it's generally good practice to disallow them in message queues.
      // However, the problem description doesn't specify, so we'll rely on ConcurrentLinkedQueue's behavior.
      // println("Warning: Enqueuing a null message."); // Example logging
    }
    queue.offer(message); // offer is generally preferred to add for capacity-constrained queues, but for CLQ, add works too.
  }

  /**
   * Removes and returns the message from the head of the queue.
   * This operation is thread-safe.
   * @return The message at the head of the queue, or null if the queue is empty.
   */
  public BaseMessage dequeue() {
    return queue.poll();
  }

  /**
   * Checks if the queue is empty.
   * This operation is thread-safe but can be misleading in concurrent scenarios
   * as the state can change immediately after the call.
   * @return true if the queue is empty, false otherwise.
   */
  public boolean isEmpty() {
    return queue.isEmpty();
  }

  /**
   * Returns the number of messages in the queue.
   * This operation is thread-safe but can be misleading in concurrent scenarios
   * as the state can change immediately after the call. The size is typically
   * an O(N) operation for ConcurrentLinkedQueue.
   * @return The number of messages in the queue.
   */
  public int size() {
    return queue.size();
  }
}
