class TestService extends BaseService {
  DataBus bus; // Though not used in this simple example, it's good practice to have it if other services need it

  TestService(DataBus bus, int loopDelay) {
    super(loopDelay);
    this.bus = bus;
  }

  void setup() {
    // No specific setup needed for this service
  }

  void loop() {
    println("TestService running...");
  }
}
