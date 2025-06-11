class DebugMonitor { //<>// //<>// //<>// //<>//
  // Program debug monitor
  // Memory, threads, ...

  // Constants
  private final long MB = 1024 * 1024;
  private Runtime runtime;
  private StringBuilder textBuilder;

  // Reference to the PApplet to draw on
  private PApplet canvas;

  // Cache for performance
  private long lastUpdateFrame = -1;
  private long cachedTotalMB = 0;
  private long cachedUsedMB = 0;
  private long cachedFreeMB = 0;
  private long cachedMaxMB = 0;
  private int cachedFPS = 0;

  // Memory monitoring over time
  private ArrayList<Long> memoryHistory;
  private ArrayList<Integer> gcEvents;
  private long lastUsedMemory = 0;
  private int frameCounter = 0;

  // Display mode
  private boolean showGraph = true;
  private boolean showDetailed = false;

  // Constructor that accepts the canvas to draw on
  DebugMonitor(PApplet targetCanvas) {
    this.canvas = targetCanvas;
    runtime = Runtime.getRuntime();
    textBuilder = new StringBuilder(300);
    memoryHistory = new ArrayList<Long>();
    gcEvents = new ArrayList<Integer>();
  }

  void update() {
    frameCounter++;

    // Update cache every 10 frames for performance
    if (canvas.frameCount != lastUpdateFrame && canvas.frameCount % 10 == 0) {
      updateCache();
      lastUpdateFrame = canvas.frameCount;
    }

    // Detect GC events
    detectGarbageCollection();

    // Maintain memory history
    if (frameCounter % 5 == 0) { // Every 5 frames to avoid overload
      memoryHistory.add(cachedUsedMB * MB);
      if (memoryHistory.size() > 200) { // Keep last 200 points
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

    // Detect GC if memory drops drastically (>30%)
    if (lastUsedMemory > 0 && currentUsed < lastUsedMemory * 0.7) {
      gcEvents.add(frameCounter);
      println("GC Event #" + gcEvents.size() + " at frame " + frameCounter +
        " - Memory: " + (lastUsedMemory/MB) + "MB → " + (currentUsed/MB) + "MB");

      // Keep only last 20 GC events
      if (gcEvents.size() > 20) {
        gcEvents.remove(0);
      }
    }

    lastUsedMemory = currentUsed;
  }

  // Standard display
  void display(HashMap<Long, String> threadLogs) {
    displayMemoryInfo();
    displayThreadLogs(threadLogs);

    if (showGraph) {
      displayMemoryGraph();
    }
  }

  /**
   * Displays detailed debugging information, including memory stats, thread logs,
   * and service-specific performance metrics.
   * @param scheduler The ServiceScheduler instance, used to fetch service metrics.
   * @param threadLogs A map of thread logs to display.
   */
  void displayDetailed(ServiceScheduler scheduler, HashMap<Long, String> threadLogs) {
    showDetailed = true;
    displayDetailedInfo(scheduler, threadLogs); // Pass scheduler
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

    // Memory health indicator
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

    // Graphic background
    canvas.fill(0, 100);
    canvas.rect(graphX, graphY, graphW, graphH);

    // Memory line
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

    // GC event markers
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

  /**
   * Displays performance and error metrics for each service.
   * Fetches metrics from the ServiceScheduler and formats them for display.
   * @param scheduler The ServiceScheduler instance to query for metrics.
   * @param x The base X-coordinate for drawing the text.
   * @param initialY The initial Y-coordinate to start drawing from.
   * @return The Y-coordinate after drawing the metrics, for subsequent drawing operations.
   */
  private int displayServiceMetrics(ServiceScheduler scheduler, int x, int initialY) {
    int y = initialY;
    int lineHeight = 18; // Assuming same lineHeight as displayDetailedInfo, or make it a field

    Map<String, ServiceMetrics> allMetrics = scheduler.getAllServiceMetrics();

    if (allMetrics == null || allMetrics.isEmpty()) {
      canvas.fill(200, 200, 255); // Light blue or similar for info message
      textBuilder.setLength(0);
      textBuilder.append("No service metrics available.");
      canvas.text(textBuilder.toString(), x, y);
      y += lineHeight;
      return y;
    }

    y += lineHeight; // Space before the header
    canvas.fill(200, 200, 255); // Different color for metrics section header
    textBuilder.setLength(0);
    textBuilder.append("SERVICE METRICS:");
    canvas.text(textBuilder.toString(), x, y);
    y += lineHeight;

    canvas.fill(220, 220, 240); // Slightly different fill for metrics text

    for (Map.Entry<String, ServiceMetrics> entry : allMetrics.entrySet()) {
      String serviceName = entry.getKey();
      ServiceMetrics metrics = entry.getValue();

      textBuilder.setLength(0);
      textBuilder.append(serviceName).append(":");
      canvas.text(textBuilder.toString(), x, y);
      y += lineHeight;

      textBuilder.setLength(0);
      textBuilder.append("  Loop Count: ").append(metrics.getLoopExecutionCount());
      canvas.text(textBuilder.toString(), x + 10, y); // Indent details
      y += lineHeight;

      textBuilder.setLength(0);
      textBuilder.append("  Avg Loop Time: ").append(String.format("%.3f ms", metrics.getAverageLoopTimeMillis()));
      canvas.text(textBuilder.toString(), x + 10, y);
      y += lineHeight;

      textBuilder.setLength(0);
      textBuilder.append("  Min Loop Time: ").append(String.format("%.3f ms", metrics.getMinLoopExecutionTimeNanos() / 1_000_000.0));
      canvas.text(textBuilder.toString(), x + 10, y);
      y += lineHeight;

      textBuilder.setLength(0);
      textBuilder.append("  Max Loop Time: ").append(String.format("%.3f ms", metrics.getMaxLoopExecutionTimeNanos() / 1_000_000.0));
      canvas.text(textBuilder.toString(), x + 10, y);
      y += lineHeight;

      textBuilder.setLength(0);
      textBuilder.append("  Error Count: ").append(metrics.getErrorCount());
      canvas.text(textBuilder.toString(), x + 10, y);
      y += lineHeight;

      y += lineHeight / 2; // Small vertical space after metrics for each service
    }
    return y;
  }

  /**
   * Central method for drawing all detailed debug information on the canvas.
   * This includes memory usage, performance (FPS), thread logs, and service metrics.
   * @param scheduler The ServiceScheduler instance, passed through to displayServiceMetrics.
   * @param threadLogs A map of thread logs to display.
   */
  private void displayDetailedInfo(ServiceScheduler scheduler, HashMap<Long, String> threadLogs) {
    int x = canvas.width/2;
    int y = 20;
    int lineHeight = 18;

    canvas.fill(255, 255, 0);
    textBuilder.setLength(0);
    textBuilder.append("= DEBUG MONITOR (Frame: ").append(canvas.frameCount).append(") =");
    canvas.text(textBuilder.toString(), x, y);

    // Detailed memory
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
      if (y > canvas.height - 50) break; // Don't go off screen
      canvas.text(logMessage, x, y);
    }

    // Display Service Metrics
    y += lineHeight; // Add some space before metrics
    y = displayServiceMetrics(scheduler, x, y); // Call the new method and update y

    if (showGraph) {
      displayMemoryGraph();
    }
  }

  // Control methods
  void toggleGraph() {
    showGraph = !showGraph;
  }
  void forceGC() {
    System.gc();
  }

  // Statistics
  void printStats() {
    println("=== Monitor Stats ===");
    println("Memoria: " + cachedUsedMB + "/" + cachedMaxMB + " MB");
    println("GC Events: " + gcEvents.size());
    println("FPS: " + cachedFPS);
    println("History points: " + memoryHistory.size());
  }
}
