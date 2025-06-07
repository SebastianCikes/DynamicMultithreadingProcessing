class LoggingService extends BaseService {

  public LoggingService(ServiceScheduler scheduler, int loopDelay) {
    super(scheduler, loopDelay);
  }

  @Override
  void setup() {
    println("LoggingService Started. Ready to receive messages on thread " + Thread.currentThread().getName() + " (ID: " + Thread.currentThread().getId() + ")");
  }

  @Override
  void processMessage(BaseMessage message) {
    if (message == null) {
      println("LoggingService received a null message.");
      return;
    }
    // Basic logging format
    String logEntry = "Log (" + Thread.currentThread().getName() + "): " +
                      "Type='" + message.messageType + 
                      "', TS=" + message.timestamp + 
                      ", Content: " + messageToString(message);
    println(logEntry);

    // Example of how LoggingService could forward or react (not part of this subtask)
    // if (message instanceof RawDataMessage && ((RawDataMessage)message).payload.contains("CRITICAL")) {
    //   BaseMessage alert = new BaseMessage(); // Simplified, would be specific alert type
    //   this.scheduler.sendMessageToService("AlertService", alert); 
    // }
  }

  private String messageToString(BaseMessage msg) {
    if (msg instanceof RawDataMessage) {
      return "RawDataMessage(payload='" + ((RawDataMessage)msg).payload + "')";
    } else if (msg instanceof ParsedDataMessage) {
      return "ParsedDataMessage(parsedContent='" + ((ParsedDataMessage)msg).parsedContent + "')";
    }
    // Add more types as they are created, e.g.:
    // else if (msg instanceof SystemStatusMessage) {
    //   return "SystemStatusMessage(status='" + ((SystemStatusMessage)msg).status + "')";
    // }
    return "Generic BaseMessage (specific content not displayed by LoggingService.messageToString)";
  }
}
