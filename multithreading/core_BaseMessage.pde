abstract class BaseMessage {
  public final long timestamp;
  public final String messageType; // Using final as it's set once in constructor

  public BaseMessage() {
    this.timestamp = System.currentTimeMillis();
    this.messageType = getClass().getSimpleName();
  }

  // Potentially add a common method to display message info, e.g.,
  // public String getInfo() {
  //   return "Type: " + messageType + ", Timestamp: " + timestamp;
  // }
}
