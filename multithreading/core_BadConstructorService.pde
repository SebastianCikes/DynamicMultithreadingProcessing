class BadConstructorService extends BaseService {
  // This service intentionally lacks a (DataBus bus) constructor
  // to test NoSuchMethodException handling.
  public BadConstructorService() {
    // Default constructor
  }

  void setup() {
    println("BadConstructorService setup.");
  }

  void loop() {
    // Does nothing
  }
}
