class DebugMonitor { //<>// //<>//
  // Monitor di debug programma
  // Memoria, thread, ...

  // Costanti
  private final long MB = 1024 * 1024;
  private Runtime runtime;
  private StringBuilder textBuilder;

  // Riferimento al PApplet su cui disegnare
  private PApplet canvas;

  // Cache per performance
  private long lastUpdateFrame = -1;
  private long cachedTotalMB = 0;
  private long cachedUsedMB = 0;
  private long cachedFreeMB = 0;
  private long cachedMaxMB = 0;
  private int cachedFPS = 0;

  // Monitoring memoria nel tempo
  private ArrayList<Long> memoryHistory;
  private ArrayList<Integer> gcEvents;
  private long lastUsedMemory = 0;
  private int frameCounter = 0;

  // Modalità display
  private boolean showGraph = true;
  private boolean showDetailed = false;

  // Costruttore che accetta il canvas su cui disegnare
  DebugMonitor(PApplet targetCanvas) {
    this.canvas = targetCanvas;
    runtime = Runtime.getRuntime();
    textBuilder = new StringBuilder(300);
    memoryHistory = new ArrayList<Long>();
    gcEvents = new ArrayList<Integer>();
  }

  void update() {
    frameCounter++;

    // Aggiorna cache ogni 10 frame per performance
    if (canvas.frameCount != lastUpdateFrame && canvas.frameCount % 10 == 0) {
      updateCache();
      lastUpdateFrame = canvas.frameCount;
    }

    // Rileva eventi GC
    detectGarbageCollection();

    // Mantieni storia memoria
    if (frameCounter % 5 == 0) { // Ogni 5 frame per non sovraccaricare
      memoryHistory.add(cachedUsedMB * MB);
      if (memoryHistory.size() > 200) { // Mantieni ultimi 200 punti
        memoryHistory.remove(0);
      }
    }
  }

  private void updateCache() {
    long totalMemory = runtime.totalMemory();
    long freeMemory = runtime.freeMemory();
    long maxMemory = runtime.maxMemory();

    cachedTotalMB = totalMemory / MB;
    cachedFreeMB = freeMemory / MB;
    cachedUsedMB = cachedTotalMB - cachedFreeMB;
    cachedMaxMB = maxMemory / MB;
    cachedFPS = int(frameRate);
    //cachedFPS = int(canvas.frameRate);
  }

  private void detectGarbageCollection() {
    long currentUsed = cachedUsedMB * MB;

    // Rileva GC se memoria scende drasticamente (>30%)
    if (lastUsedMemory > 0 && currentUsed < lastUsedMemory * 0.7) {
      gcEvents.add(frameCounter);
      println("GC Event #" + gcEvents.size() + " at frame " + frameCounter +
        " - Memory: " + (lastUsedMemory/MB) + "MB → " + (currentUsed/MB) + "MB");

      // Mantieni solo ultimi 20 eventi GC
      if (gcEvents.size() > 20) {
        gcEvents.remove(0);
      }
    }

    lastUsedMemory = currentUsed;
  }

  // Display standard
  void display(HashMap<Long, String> threadLogs) {
    displayMemoryInfo();
    displayThreadLogs(threadLogs);

    if (showGraph) {
      displayMemoryGraph();
    }
  }

  // Display dettagliato con tutte le info
  void displayDetailed(HashMap<Long, String> threadLogs) {
    showDetailed = true;
    displayDetailedInfo(threadLogs);
    showDetailed = false;
  }

  private void displayMemoryInfo() {
    int baseY = canvas.height - 100;
    int x = canvas.width / 2;

    canvas.fill(255);

    textBuilder.setLength(0);
    textBuilder.append("FPS: ").append(cachedFPS);
    canvas.text(textBuilder.toString(), x, baseY);

    textBuilder.setLength(0);
    textBuilder.append("Memoria: ").append(cachedUsedMB).append("/").append(cachedMaxMB).append(" MB");
    canvas.text(textBuilder.toString(), x, baseY + 20);

    textBuilder.setLength(0);
    textBuilder.append("GC Events: ").append(gcEvents.size());
    canvas.text(textBuilder.toString(), x, baseY + 40);

    // Indicatore di salute memoria
    float memoryPercent = (float)cachedUsedMB / cachedMaxMB;
    canvas.fill(memoryPercent > 0.8 ? canvas.color(255, 0, 0) : memoryPercent > 0.6 ? canvas.color(255, 255, 0) : canvas.color(0, 255, 0));
    textBuilder.setLength(0);
    textBuilder.append("Utilizzo: ").append(int(memoryPercent * 100)).append("%");
    canvas.text(textBuilder.toString(), x, baseY + 60);
  }

  private void displayThreadLogs(HashMap<Long, String> threadLogs) {
    canvas.fill(255);
    int x = canvas.width / 2;
    int startY = 60;
    int lineHeight = 50;
    int i = 0;

    for (String logMessage : threadLogs.values()) {
      i++;
      canvas.text(logMessage, x, startY + (i * lineHeight));
    }
  }

  private void displayMemoryGraph() {
    if (memoryHistory.size() < 2) return;

    int graphX = 20;
    int graphY = 20;
    int graphW = 200;
    int graphH = 80;

    // Background grafico
    canvas.fill(0, 100);
    canvas.rect(graphX, graphY, graphW, graphH);

    // Linea memoria
    canvas.stroke(0, 255, 0);
    canvas.strokeWeight(1);
    canvas.noFill();
    canvas.beginShape();

    for (int i = 0; i < memoryHistory.size(); i++) {
      float x = map(i, 0, memoryHistory.size()-1, graphX, graphX + graphW);
      float y = map(memoryHistory.get(i), 0, cachedMaxMB * MB, graphY + graphH, graphY);
      canvas.vertex(x, y);
    }
    canvas.endShape();

    // Marker eventi GC
    canvas.stroke(255, 0, 0);
    canvas.strokeWeight(2);
    for (Integer gcFrame : gcEvents) {
      if (frameCounter - gcFrame < memoryHistory.size() * 5) {
        float x = map(frameCounter - gcFrame, memoryHistory.size() * 5, 0, graphX, graphX + graphW);
        canvas.line(x, graphY, x, graphY + graphH);
      }
    }

    canvas.strokeWeight(1);
  }

  private void displayDetailedInfo(HashMap<Long, String> threadLogs) {
    int x = canvas.width/2;
    int y = 150;
    int lineHeight = 18;

    canvas.fill(255, 255, 0);
    textBuilder.setLength(0);
    textBuilder.append("= DEBUG MONITOR (Frame: ").append(canvas.frameCount).append(") =");
    canvas.text(textBuilder.toString(), x, y);

    // Memoria dettagliata
    canvas.fill(255);
    y += lineHeight * 2;
    canvas.text("MEMORIA:", x, y);

    y += lineHeight;
    textBuilder.setLength(0);
    textBuilder.append("  Usata: ").append(cachedUsedMB).append(" MB (")
      .append(int((float)cachedUsedMB/cachedMaxMB*100)).append("%)");
    canvas.text(textBuilder.toString(), x, y);

    y += lineHeight;
    textBuilder.setLength(0);
    textBuilder.append("  Totale: ").append(cachedMaxMB).append(" MB");
    canvas.text(textBuilder.toString(), x, y);

    y += lineHeight;
    textBuilder.setLength(0);
    textBuilder.append("  Eventi GC: ").append(gcEvents.size());
    canvas.text(textBuilder.toString(), x, y);

    // Performance
    y += lineHeight * 2;
    canvas.text("PERFORMANCE:", x, y);
    y += lineHeight;
    textBuilder.setLength(0);
    textBuilder.append("  FPS: ").append(cachedFPS).append(" (target: " + refreshRate + ")");
    canvas.text(textBuilder.toString(), x, y);

    // Thread info
    y += lineHeight * 2;
    canvas.fill(0, 255, 0);
    textBuilder.setLength(0);
    textBuilder.append("THREADS (").append(threadLogs.size()).append(" attivi):");
    canvas.text(textBuilder.toString(), x, y);

    canvas.fill(255);
    for (String logMessage : threadLogs.values()) {
      y += lineHeight;
      if (y > canvas.height - 50) break; // Non uscire dallo schermo
      canvas.text(logMessage, x, y);
    }

    if (showGraph) {
      displayMemoryGraph();
    }
  }

  // Metodi di controllo
  void toggleGraph() {
    showGraph = !showGraph;
  }
  void forceGC() {
    System.gc();
  }

  // Statistiche
  void printStats() {
    println("=== Monitor Stats ===");
    println("Memoria: " + cachedUsedMB + "/" + cachedMaxMB + " MB");
    println("GC Events: " + gcEvents.size());
    println("FPS: " + cachedFPS);
    println("History points: " + memoryHistory.size());
  }
}
