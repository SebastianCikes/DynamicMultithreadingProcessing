import java.util.Queue;
// import java.util.concurrent.ConcurrentLinkedQueue; // No longer used
import java.util.concurrent.ArrayBlockingQueue;

class MessageQueue {
  private static final int DEFAULT_CAPACITY = 256; // Default capacity for the bounded queue
  private final Queue<BaseMessage> queue; // Type is Queue, implementation is ArrayBlockingQueue

  /**
   * Constructs a new MessageQueue with default capacity.
   */
  public MessageQueue() {
    this.queue = new ArrayBlockingQueue<BaseMessage>(DEFAULT_CAPACITY);
  }

  /**
   * Constructs a new MessageQueue with specified capacity.
   * @param capacity The maximum capacity of the queue.
   */
  public MessageQueue(int capacity) {
    if (capacity <= 0) {
      throw new IllegalArgumentException("Queue capacity must be positive.");
    }
    this.queue = new ArrayBlockingQueue<BaseMessage>(capacity);
  }

  /**
   * Adds a message to the end of the queue if space is available.
   * This operation is thread-safe. ArrayBlockingQueue handles synchronization.
   * @param message The message to enqueue. Cannot be null for ArrayBlockingQueue.
   * @return true if the message was added, false if the queue is full or message is null.
   */
  public boolean enqueue(BaseMessage message) {
    if (message == null) {
      // ArrayBlockingQueue does not permit null elements.
      println("MessageQueue: Attempted to enqueue a null message. Aborted.");
      return false;
    }
    // queue.offer(message) is non-blocking and returns false if full.
    return queue.offer(message);
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
