class DebugWindow extends PApplet {
  DebugMonitor monitor;
  HashMap<Long, String> currentLogs;
  ServiceScheduler scheduler;

  DebugWindow(ServiceScheduler scheduler) {
    PApplet.runSketch(new String[]{"SecondWindow"}, this);
    this.scheduler = scheduler;
  }

  public void settings() {
    size(1000, 600);
  }

  public void setup() {
    // Passa 'this' per riferirsi a questo canvas
    monitor = new DebugMonitor(this);
    currentLogs = new HashMap<Long, String>();
  }

  public void draw() {
    background(0);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(20);

    // Aggiorna e mostra il monitor
    currentLogs = scheduler.getLogs();
    monitor.update();
    monitor.displayDetailed(currentLogs);
  }

  public void keyPressed() {
    if (key == 'g') monitor.toggleGraph();    // Mostra/nascondi grafico
    if (key == 'c') monitor.forceGC();        // Forza garbage collection
    if (key == 's') monitor.printStats();     // Stampa statistiche
  }
}
