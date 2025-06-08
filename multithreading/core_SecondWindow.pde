class DebugWindow extends PApplet {
  DebugMonitor monitor;
  HashMap<Long, String> currentLogs;
  ServiceScheduler scheduler;

  DebugWindow(ServiceScheduler scheduler) {
    PApplet.runSketch(new String[]{"SecondWindow"}, this);
    this.scheduler = scheduler;
  }

  public void settings() {
    size(800, 1000);
  }

  public void setup() {
    // Pass 'this' to refer to this canvas
    monitor = new DebugMonitor(this);
    currentLogs = new HashMap<Long, String>();
  }

  public void draw() {
    background(0);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(20);

    // Update and show the monitor
    currentLogs = scheduler.getLogs();
    monitor.update();
    monitor.displayDetailed(this.scheduler, currentLogs); // Pass the scheduler instance
  }

  public void keyPressed() {
    if (key == 'g') monitor.toggleGraph();    // Show/hide graph
    if (key == 'c') monitor.forceGC();        // Force garbage collection
    if (key == 's') monitor.printStats();     // Print statistics
  }
}
