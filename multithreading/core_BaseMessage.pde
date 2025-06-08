/**
 * Abstract base class for all messages passed between services in the multithreading framework.
 * It provides common properties that all messages should have, such as a timestamp
 * and a message type identifier.
 *
 * Subclasses should extend `BaseMessage` to define specific message types with their
 * own unique payloads or data fields relevant to the information they need to convey.
 * For example, `RawDataMessage` might carry a raw string payload, while `ParsedDataMessage`
 * might carry structured data.
 *
 * Key characteristics:
 * - **Timestamped:** Each message automatically records its creation time.
 * - **Typed:** Each message automatically derives its `messageType` string from its
 *   simple class name, allowing for easy identification and type checking (e.g., using `instanceof`
 *   or by inspecting the `messageType` string).
 * - **Immutable Core Properties:** `timestamp` and `messageType` are final, ensuring they
 *   are set once at construction and cannot be changed, which is good for consistency
 *   in a multithreaded environment.
 */
abstract class BaseMessage {
  // timestamp: Stores the system time (in milliseconds since the epoch) when the message
  // object was created. This is useful for logging, metrics, or time-sensitive processing.
  public final long timestamp;

  // messageType: A string identifier for the type of the message.
  // By default, this is initialized to the simple class name of the concrete message subclass
  // (e.g., "RawDataMessage", "ParsedDataMessage"). This allows services to easily
  // determine how to handle a received message.
  public final String messageType;

  /**
   * Constructor for BaseMessage.
   * Initializes the `timestamp` to the current system time and `messageType`
   * to the simple name of the concrete class extending this BaseMessage.
   */
  public BaseMessage() {
    this.timestamp = System.currentTimeMillis();
    // getClass().getSimpleName() provides the actual class name of the object being created,
    // e.g., "RawDataMessage" if `new RawDataMessage()` is called.
    this.messageType = getClass().getSimpleName();
  }

  // Example of a common utility method that could be added to BaseMessage or its subclasses:
  // /**
  //  * Returns a string representation of the core message information.
  //  * Subclasses might override this to include payload-specific details.
  //  * @return A string containing the message type and timestamp.
  //  */
  // @Override
  // public String toString() {
  //   return "Message Type: " + messageType + ", Timestamp: " + timestamp;
  // }
}
