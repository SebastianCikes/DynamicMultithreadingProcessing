class ParserService extends BaseService {

  // Constructor now takes ServiceScheduler
  ParserService(ServiceScheduler scheduler, int loopDelay) {
    super(scheduler, loopDelay); // Call super constructor with scheduler
    // this.bus = bus; // DataBus is no longer used directly
  }

  void setup() {
    // initialization if necessary
    println("ParserService setup complete. Waiting for messages...");
  }

  // processMessage is called by BaseService's loop
  @Override
    void processMessage(BaseMessage message) {
    if (message instanceof RawDataMessage) {
      RawDataMessage rawMessage = (RawDataMessage) message;
      String rawPayload = rawMessage.payload;

      // Perform the parsing logic
      if (rawPayload != null && rawPayload.startsWith("DATA_")) {
        String[] parts = rawPayload.split("_", 2); // Split only on the first underscore
        if (parts.length > 1) {
          String parsedContent = "Elaborato: " + parts[1];
          println("ParserService successfully parsed: " + parsedContent + " from message " + message.messageType + " ts: " + message.timestamp);

          // Create a ParsedDataMessage
          ParsedDataMessage psm = new ParsedDataMessage(parsedContent);

          // Send this message to LoggingService
          if (this.scheduler != null) {
            boolean sent = this.scheduler.sendMessageToService("LoggingService", psm);
            if (sent) {
              //println("ParserService sent ParsedDataMessage to LoggingService."); // Can be verbose
            } else {
              println("ParserService failed to send ParsedDataMessage to LoggingService (LoggingService not found or message null).");
            }
          } else {
            println("ParserService: Scheduler not available, cannot send ParsedDataMessage.");
          }
        } else {
          println("ParserService received RawDataMessage with malformed payload: " + rawPayload);
        }
      } else {
        println("ParserService received RawDataMessage with non-DATA_ payload: " + rawPayload);
      }
    } else if (message != null) {
      // Handle other message types if necessary, or log unexpected messages
      println("ParserService received unexpected message type: " + message.messageType + " Content: " + message.toString());
    } else {
      println("ParserService received a null message in processMessage.");
    }
    // loop() method is inherited from BaseService and should not be overridden here.
  }
}
