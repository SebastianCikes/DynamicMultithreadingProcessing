/**
 * Holds performance and error metrics for a BaseService instance.
 * All time durations are stored in nanoseconds.
 */
class ServiceMetrics {
  long loopExecutionCount;
  long totalLoopExecutionTimeNanos;
  long minLoopExecutionTimeNanos;
  long maxLoopExecutionTimeNanos;
  long errorCount;

  private String serviceName; // For identification in logs or UI

  /**
   * Constructor for ServiceMetrics.
   * Initializes metrics to default values.
   * @param serviceName The name of the service these metrics are for.
   */
  ServiceMetrics(String serviceName) {
    this.serviceName = serviceName;
    reset();
  }

  /**
   * Records a single loop execution time.
   * Updates the total execution time, count, min, and max times.
   * @param durationNanos The duration of the loop execution in nanoseconds.
   */
  public synchronized void recordLoopTime(long durationNanos) {
    loopExecutionCount++;
    totalLoopExecutionTimeNanos += durationNanos;
    if (durationNanos < minLoopExecutionTimeNanos) {
      minLoopExecutionTimeNanos = durationNanos;
    }
    if (durationNanos > maxLoopExecutionTimeNanos) {
      maxLoopExecutionTimeNanos = durationNanos;
    }
  }

  /**
   * Increments the error count for the service.
   */
  public synchronized void incrementErrorCount() {
    errorCount++;
  }

  /**
   * Calculates the average loop execution time in nanoseconds.
   * @return Average time in nanoseconds, or 0 if no loops have been recorded.
   */
  public synchronized double getAverageLoopTimeNanos() {
    if (loopExecutionCount == 0) {
      return 0.0;
    }
    return (double)totalLoopExecutionTimeNanos / loopExecutionCount;
  }

  /**
   * Calculates the average loop execution time in milliseconds.
   * @return Average time in milliseconds, or 0 if no loops have been recorded.
   */
  public synchronized double getAverageLoopTimeMillis() {
    if (loopExecutionCount == 0) {
      return 0.0;
    }
    return (double)totalLoopExecutionTimeNanos / loopExecutionCount / 1_000_000.0;
  }

  /**
   * Resets all metrics to their initial states.
   */
  public synchronized void reset() {
    loopExecutionCount = 0;
    totalLoopExecutionTimeNanos = 0;
    minLoopExecutionTimeNanos = Long.MAX_VALUE;
    maxLoopExecutionTimeNanos = 0; // Or Long.MIN_VALUE, but 0 is fine if we only record positive durations
    errorCount = 0;
  }

  // Getters
  public synchronized String getServiceName() {
    return serviceName;
  }
  public synchronized long getLoopExecutionCount() {
    return loopExecutionCount;
  }
  public synchronized long getTotalLoopExecutionTimeNanos() {
    return totalLoopExecutionTimeNanos;
  }
  public synchronized long getMinLoopExecutionTimeNanos() {
    return minLoopExecutionTimeNanos == Long.MAX_VALUE ? 0 : minLoopExecutionTimeNanos;
  }
  public synchronized long getMaxLoopExecutionTimeNanos() {
    return maxLoopExecutionTimeNanos;
  }
  public synchronized long getErrorCount() {
    return errorCount;
  }

  @Override
    public synchronized String toString() {
    return "Metrics for " + serviceName + ": " +
      "Count=" + loopExecutionCount +
      ", AvgTime(ms)=" + String.format("%.4f", getAverageLoopTimeMillis()) +
      ", MinTime(ms)=" + String.format("%.4f", (minLoopExecutionTimeNanos == Long.MAX_VALUE ? 0 : minLoopExecutionTimeNanos / 1_000_000.0)) +
      ", MaxTime(ms)=" + String.format("%.4f", (maxLoopExecutionTimeNanos / 1_000_000.0)) +
      ", Errors=" + errorCount;
  }
}
