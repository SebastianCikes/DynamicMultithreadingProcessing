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
    BaseMessage message;
    // Process all messages currently in the queue before delaying.
    while ((message = inputQueue.dequeue()) != null) {
      if (!running) { // Check running state before each message processing
        // If service was stopped, messages currently in queue (after this one) will be processed on next scheduler cycle if service is restarted.
        // Or, they might be lost if the service is not restarted.
        // For now, just break the processing loop for this iteration.
        // Re-enqueuing 'message' could be an option: inputQueue.enqueue(message);
        println("Service " + getClass().getSimpleName() + " stopping during message processing batch, " + (inputQueue.size() +1) + " messages were in flight (current one incl.).");
        break; 
      }
      processMessage(message);
    }
  }

  public void run() {
    setup();
    while (running) {
      loop(); // Processes all available messages in the inputQueue
      delay(loopDelay); // Uses Processing's delay function
    }
    // Final log when the service's run loop actually exits.
    println(getClass().getSimpleName() + " has finished its run loop.");
  }

  public void stop() {
    running = false;
  }

  public int getPriority() {
    return 5; // default
  }
}
