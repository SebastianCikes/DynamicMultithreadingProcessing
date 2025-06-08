import java.util.Queue;
// The previously used ConcurrentLinkedQueue is unbounded, which could lead to memory issues
// if messages are produced much faster than they are consumed.
// ArrayBlockingQueue is a bounded, blocking queue that provides thread-safety
// and helps prevent out-of-memory errors by enforcing a capacity limit.
import java.util.concurrent.ArrayBlockingQueue;

/**
 * A thread-safe message queue for inter-service communication, implemented using {@link ArrayBlockingQueue}.
 * This queue is used by each `BaseService` to store incoming messages.
 * It provides a fixed-capacity, bounded queue which helps in preventing uncontrolled memory growth
 * if messages are produced faster than they can be consumed.
 *
 * Key features:
 * - **Thread-Safety:** `ArrayBlockingQueue` handles internal synchronization, making `enqueue` and `dequeue`
 *   operations safe for concurrent use by multiple threads (e.g., a service processing its queue
 *   while other services or threads enqueue messages).
 * - **Bounded Capacity:** Helps in applying backpressure. If the queue is full, `enqueue` (using `offer`)
 *   will return `false` rather than blocking or throwing an exception, allowing the producer to handle
 *   the full queue scenario (e.g., by logging, retrying, or dropping the message).
 * - **No Null Elements:** `ArrayBlockingQueue` does not permit null elements. This is handled in the
 *   `enqueue` method.
 */
class MessageQueue {
  // DEFAULT_CAPACITY: The default maximum number of messages the queue can hold if no specific
  // capacity is provided in the constructor.
  private static final int DEFAULT_CAPACITY = 256;

  // queue: The underlying `ArrayBlockingQueue` instance that stores the messages.
  // It is typed to hold `BaseMessage` objects, allowing various message types to be enqueued.
  private final Queue<BaseMessage> queue;

  /**
   * Constructs a new `MessageQueue` with the {@link #DEFAULT_CAPACITY}.
   */
  public MessageQueue() {
    this.queue = new ArrayBlockingQueue<BaseMessage>(DEFAULT_CAPACITY);
  }

  /**
   * Constructs a new `MessageQueue` with the specified capacity.
   *
   * @param capacity The maximum number of messages this queue can hold. Must be positive.
   * @throws IllegalArgumentException if the specified capacity is not positive.
   */
  public MessageQueue(int capacity) {
    if (capacity <= 0) {
      throw new IllegalArgumentException("MessageQueue capacity must be positive. Received: " + capacity);
    }
    this.queue = new ArrayBlockingQueue<BaseMessage>(capacity);
  }

  /**
   * Adds a message to the end (tail) of the queue if space is available.
   * This operation is thread-safe as `ArrayBlockingQueue.offer()` is thread-safe.
   * It uses `offer()` which is non-blocking and returns `false` if the queue is full,
   * preventing the caller from blocking indefinitely.
   *
   * @param message The `BaseMessage` to enqueue. Null messages are not permitted and will be rejected.
   * @return `true` if the message was successfully added to the queue,
   *         `false` if the queue is full or if the message is null.
   */
  public boolean enqueue(BaseMessage message) {
    if (message == null) {
      // ArrayBlockingQueue does not permit null elements. Log and return false.
      println("MessageQueue Error: Attempted to enqueue a null message. Operation aborted.");
      return false;
    }
    // queue.offer(message) attempts to add the message and returns false if the queue is full.
    // This is a non-blocking way to handle a full queue.
    boolean offered = queue.offer(message);
    if (!offered) {
      println("MessageQueue Warning: Queue is full (capacity: " + ((ArrayBlockingQueue<BaseMessage>)queue).remainingCapacity() +
        "). Failed to enqueue message of type: " + message.messageType);
    }
    return offered;
  }

  /**
   * Removes and returns the message from the head of the queue.
   * This operation is thread-safe as `ArrayBlockingQueue.poll()` is thread-safe.
   * `poll()` is non-blocking and returns `null` if the queue is empty.
   *
   * @return The `BaseMessage` at the head of the queue, or `null` if the queue is empty.
   */
  public BaseMessage dequeue() {
    // queue.poll() retrieves and removes the head of this queue,
    // or returns null if this queue is empty.
    return queue.poll();
  }

  /**
   * Checks if the queue is empty.
   * This operation is thread-safe. However, the state of the queue can change
   * immediately after this call in a concurrent environment. For example, another thread
   * might add an element right after `isEmpty()` returns `true`.
   *
   * @return `true` if the queue contains no messages, `false` otherwise.
   */
  public boolean isEmpty() {
    return queue.isEmpty();
  }

  /**
   * Returns the current number of messages in the queue.
   * This operation is thread-safe. Similar to `isEmpty()`, the returned size can change
   * immediately in a concurrent setting. It reflects the size at a specific moment in time.
   * For `ArrayBlockingQueue`, `size()` is an O(1) operation.
   *
   * @return The number of messages currently in the queue.
   */
  public int size() {
    return queue.size();
  }
}
