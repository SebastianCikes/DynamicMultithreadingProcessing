abstract class BaseService implements Runnable {
  // Come deve essere impostata una classe
  
  volatile boolean running = true;

  abstract void setup();
  abstract void loop();

  public void run() {
    setup();
    while (running) {
      loop();
      delay(10);
    }
  }

  public void stop() {
    running = false;
  }

  public int getPriority() {
    return 5; // default
  }
}
