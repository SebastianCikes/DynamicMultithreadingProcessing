class TestService extends BaseService {
  DataBus bus; // Though not used in this simple example, it's good practice to have it if other services need it

  // Constructor now takes ServiceScheduler
  TestService(DataBus bus, ServiceScheduler scheduler, int loopDelay) {
    super(scheduler, loopDelay); // Call super constructor with scheduler
    this.bus = bus;
  }

  void setup() {
    // No specific setup needed for this service
    println("TestService setup complete.");
  }

  // This loop method will be overridden by BaseService.loop().
  // To make TestService do something, processMessage should be implemented.
  void loop() {
    println("TestService custom loop (will not be called if processMessage is not implemented and BaseService.loop is used)...");
  }

  // Required by BaseService, otherwise it won't compile as BaseService.processMessage is abstract
  @Override
  void processMessage(BaseMessage message) {
    // For now, just acknowledge a message if received.
    if (message != null) {
      println("TestService received message: " + message.messageType);
    }
    // To make it "run" like before, it could print its status here,
    // but it would print on every message or every loopDelay if queue is empty.
    // The original "TestService running..." was on every loopDelay.
    // We can add a simple println here to indicate it's alive when its processMessage is called.
    // However, its original behavior was to print regardless of messages.
    // For now, let's keep it message-focused or silent if no messages.
  }
}
