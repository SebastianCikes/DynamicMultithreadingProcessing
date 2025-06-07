abstract class BaseService implements Runnable {
  // Come deve essere impostata una classe
  int loopDelay = 10; // Default loop delay
  protected final MessageQueue inputQueue; // Input queue for the service
  protected ServiceScheduler scheduler; // Reference to the scheduler for sending messages
  
  volatile boolean running = true;

  // Constructor
  BaseService(ServiceScheduler scheduler, int loopDelay) {
    this.scheduler = scheduler; // Store the scheduler instance
    if (loopDelay <= 0) {
      this.loopDelay = 10; // Default if invalid value is passed
    } else {
      this.loopDelay = loopDelay;
    }
    this.inputQueue = new MessageQueue();
  }

  abstract void setup();
  abstract void processMessage(BaseMessage message); // New abstract method for message processing

  // Loop method now dequeues and processes messages
  void loop() {
    BaseMessage message = inputQueue.dequeue();
    if (message != null) {
      processMessage(message);
    }
  }

  public void run() {
    setup();
    while (running) {
      loop(); // Polls queue and processes one message if available
      delay(loopDelay); // Use configurable loopDelay
    }
  }

  public void stop() {
    running = false;
  }

  public int getPriority() {
    return 5; // default
  }
}
