abstract class BaseService implements Runnable {
  // Come deve essere impostata una classe
  int loopDelay = 10; // Default loop delay
  
  volatile boolean running = true;

  // Constructor
  BaseService(int loopDelay) {
    if (loopDelay <= 0) {
      this.loopDelay = 10; // Default if invalid value is passed
    } else {
      this.loopDelay = loopDelay;
    }
  }

  abstract void setup();
  abstract void loop();

  public void run() {
    setup();
    while (running) {
      loop();
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
