class BadConstructorService extends BaseService {
  // This service intentionally lacks a (DataBus bus) constructor
  // (or more accurately, a constructor matching reflection attempts)
  // to test NoSuchMethodException handling.
  public BadConstructorService() {
    // Call super constructor with null for scheduler and a default loopDelay.
    // This makes it compile, but it won't be found by reflection 
    // if reflection expects a ServiceScheduler instance.
    super(null, 1000); 
  }

  void setup() {
    println("BadConstructorService setup.");
  }

  // This loop method will be overridden by BaseService.loop().
  void loop() {
    // Does nothing effectively
  }

  // Required by BaseService to be concrete
  @Override
  void processMessage(BaseMessage message) {
    // This service isn't expected to do much.
    // Log if it ever receives a message.
    if (message != null) {
      println("BadConstructorService unexpectedly received message: " + message.messageType);
    }
  }
}
