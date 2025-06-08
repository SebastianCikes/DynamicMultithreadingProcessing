import java.util.ArrayList; // Required for ArrayList
import java.util.Collection; // Required for Collection
import java.util.HashMap;
import java.util.Map;

/**
 * Manages the lifecycle of services and distributes them across a pool of ServiceThread instances.
 * It handles adding services, starting them, and cleaning up completed or crashed services.
 * It also provides a central point for services to send messages to each other and for logging.
 */
class ServiceScheduler {

  // A map of all registered services, keyed by their simple class name.
  // This allows for quick lookup of any service instance by its name.
  private final Map<String, BaseService> allServicesByName = new HashMap<String, BaseService>();

  // Stores log messages, typically keyed by ServiceThread ID, summarizing the services they manage.
  HashMap<Long, String> logs = new HashMap<Long, String>();

  // List of ServiceThread instances that will execute the services.
  ArrayList<ServiceThread> threads;
  int maxThreads; // Maximum number of ServiceThread instances to create.

  // Reusable StringBuilder to avoid frequent memory allocations during log message construction.
  private StringBuilder reusableStringBuilder = new StringBuilder();

  // Counters for debugging and monitoring purposes.
  private int totalServicesAdded = 0;
  private int totalLogUpdates = 0;

  /**
   * Constructor for ServiceScheduler.
   * Initializes the pool of ServiceThread instances.
   * @param maxThreads The number of ServiceThread instances to create and manage.
   */
  ServiceScheduler(int maxThreads) {
    this.maxThreads = maxThreads;
    this.threads = new ArrayList<ServiceThread>();
    for (int i = 0; i < maxThreads; i++) {
      threads.add(new ServiceThread());
    }
  }

  /**
   * Adds a service to a ServiceThread.
   * It tries to assign the service to a preferred thread, otherwise uses basic load balancing
   * based on the current number of services assigned to each ServiceThread.
   * @param s The service to add.
   * @param preferredThread The index of the preferred ServiceThread, or -1 for no preference.
   */
  void addService(BaseService s, int preferredThread) {
    ServiceThread targetThread = null;
    String assignmentMethod = ""; // For logging how the service was assigned

    // Attempt to assign to the preferred thread if specified and valid
    if (preferredThread >= 0 && preferredThread < threads.size()) {
      targetThread = threads.get(preferredThread);
      assignmentMethod = "preferred thread " + preferredThread;
    } else {
      if (preferredThread != -1) { // Log a warning if an invalid preference was given
        println("Warning: Preferred thread " + preferredThread + " for service " + s.getClass().getSimpleName() + " is invalid. Using load balancing.");
      }
      // Fallback to load balancing: find the ServiceThread with the fewest services
      if (!threads.isEmpty()) {
        targetThread = threads.get(0); // Start with the first thread as a candidate
        int minServices = targetThread.getAssignedServices().size();

        for (ServiceThread t : threads) {
          if (t.getAssignedServices().size() < minServices) {
            minServices = t.getAssignedServices().size();
            targetThread = t;
          }
        }
        assignmentMethod = "load balancing to thread index " + threads.indexOf(targetThread);
      } else {
        println("Error: No available ServiceThreads to assign service " + s.getClass().getSimpleName() + ". Service not added.");
        return; // Cannot assign service
      }
    }

    if (targetThread != null) {
      targetThread.addService(s);
      allServicesByName.put(s.getClass().getSimpleName(), s); // Store service by its class name for global lookup
      totalServicesAdded++;
      println("Service " + s.getClass().getSimpleName() + " assigned via " + assignmentMethod + " to " + targetThread.getName() + " (ID: " + targetThread.getId() + ")");
      updateLogForThread(targetThread); // Update the log for the affected thread
    }
  }

  /**
   * Returns the current logs.
   * @return HashMap containing log messages.
   */
  HashMap<Long, String> getLogs() {
    return logs;
  }

  /**
   * Starts all ServiceThread instances. Each ServiceThread will, in turn,
   * start all services assigned to it.
   */
  void startAll() {
    for (ServiceThread t : threads) {
      if (!t.isAlive()) { // Start the ServiceThread itself if it's not already running
        t.start();
      } else {
        // If ServiceThread's run() method is designed to pick up new services,
        // this might not be an issue. However, current ServiceThread.run() only starts initial services.
        // This implies services added after a ServiceThread has started might not auto-start
        // unless ServiceThread.run() is designed as a continuous loop (which it isn't).
        // For now, assuming ServiceThread.start() is called once.
        println("Warning: ServiceThread " + t.getName() + " is already alive. Services added post-start might not run unless run() is re-invoked or designed for it.");
      }
    }
  }

  /**
   * Prints memory and service statistics for debugging.
   * Reflects the number of services managed by each ServiceThread.
   */
  void printMemoryStats() {
    int totalActiveServicesInThreads = 0;
    for (ServiceThread t : threads) {
      totalActiveServicesInThreads += t.getAssignedServices().size(); // Changed to getAssignedServices
    }

    println("=== ServiceScheduler Stats ===");
    println("Total Services Ever Added (to scheduler): " + totalServicesAdded);
    println("Services Currently Tracked in allServicesByName: " + allServicesByName.size());
    println("Services Actively Managed in ServiceThreads: " + totalActiveServicesInThreads);
    println("Log Updates Counter: " + totalLogUpdates);
    println("Active Log Entries: " + logs.size());
    println("Number of ServiceThread instances: " + threads.size());

    if (allServicesByName.size() > totalActiveServicesInThreads) {
      println("WARNING: Mismatch between allServicesByName (" + allServicesByName.size() +
        ") and services in threads (" + totalActiveServicesInThreads +
        "). Potential leak or stale entries in allServicesByName if cleanup is not thorough.");
    }
    if (totalServicesAdded > allServicesByName.size() * 1.5 && totalServicesAdded > 10) { // Heuristic
      println("INFO: Total services added ("+totalServicesAdded+") is significantly higher than currently tracked ("+allServicesByName.size()+"). Indicates services are being added and removed, which is normal for dynamic systems.");
    }
  }

  /**
   * Periodically called to clean up services that have self-terminated (i.e., `isCompleted()` returns true).
   * It iterates through each {@link ServiceThread}, inspects its managed services,
   * and removes any service that reports it has completed.
   *
   * Service "crashes" (exceptions in `loop()`) are logged by `ServiceThread` but do not automatically
   * mark a service as completed. A separate mechanism or manual intervention would be needed for crashed
   * services if they don't also set their `running` flag to false.
   *
   * Removal involves:
   * 1. Identifying services: A service is removed if `service.isCompleted()` returns true.
   * 2. Invoking `serviceThread.removeService(serviceToRemove)`: This method within {@link ServiceThread}
   *    handles stopping the service's loop calls, calling `cleanup()`, and removing from its list.
   * 3. Removing the service from the scheduler's global tracking map `allServicesByName`.
   * After processing all threads, `updateAllLogs()` is called to refresh status messages.
   */
  void cleanupCompletedServices() {
    println("ServiceScheduler: Starting cleanup of completed services...");
    ArrayList<BaseService> servicesToRemoveFromCurrentThread;

    for (ServiceThread serviceThreadInstance : threads) {
      // Get the collection of services directly from the ServiceThread
      Collection<BaseService> assignedServices = serviceThreadInstance.getAssignedServices();
      if (assignedServices.isEmpty()) {
        continue; // No services in this ServiceThread to check.
      }

      servicesToRemoveFromCurrentThread = new ArrayList<BaseService>();

      // Identify services for removal from the current ServiceThread
      for (BaseService service : assignedServices) { // Iterate over the collection
        String serviceName = service.getClass().getSimpleName();
        if (service.isCompleted()) {
          println("ServiceScheduler: Service " + serviceName + " in " + serviceThreadInstance.getName() + " marked as completed. Scheduling for removal.");
          servicesToRemoveFromCurrentThread.add(service);
        }
      }

      // Remove identified services from the current ServiceThread and the global map
      if (!servicesToRemoveFromCurrentThread.isEmpty()) {
        println("ServiceScheduler: Removing " + servicesToRemoveFromCurrentThread.size() + " service(s) from " + serviceThreadInstance.getName() + "...");
        for (BaseService serviceToRemove : servicesToRemoveFromCurrentThread) {
          String serviceName = serviceToRemove.getClass().getSimpleName();
          println("ServiceScheduler: Processing removal of " + serviceName + " from " + serviceThreadInstance.getName());

          // Delegate the actual stopping, cleanup, and list removal to ServiceThread's removeService method
          serviceThreadInstance.removeService(serviceToRemove);

          // Then, remove from scheduler's global tracking
          BaseService removedFromGlobalMap = allServicesByName.remove(serviceName);
          if (removedFromGlobalMap != null) {
            println("ServiceScheduler: Service " + serviceName + " successfully removed from global tracking map.");
          } else {
            println("ServiceScheduler: Warning - Service " + serviceName + " was already removed or not found in global tracking map during cleanup.");
          }
        }
      }
    }

    println("ServiceScheduler: Cleanup finished. Updating all logs.");
    updateAllLogs(); // Refresh log messages after cleanup.
  }

  /**
   * Updates the log messages for all ServiceThreads.
   * This method iterates through each ServiceThread and regenerates its summary log message
   * based on the services it currently manages.
   */
  private void updateAllLogs() {
    for (ServiceThread t : threads) {
      updateLogForThread(t);
    }
  }

  /**
   * Updates the log message for a specific ServiceThread.
   * @param t The ServiceThread whose log needs updating.
   */
  private void updateLogForThread(ServiceThread t) {
    // Use getAssignedServices() which returns Collection<BaseService>
    Collection<BaseService> currentServicesInThread = t.getAssignedServices();
    if (currentServicesInThread.isEmpty()) {
      logs.remove(t.getId());
    } else {
      reusableStringBuilder.setLength(0); // Clear the reusable StringBuilder
      boolean first = true;
      for (BaseService service : currentServicesInThread) { // Iterate over the collection
        if (!first) {
          reusableStringBuilder.append(", ");
        }
        reusableStringBuilder.append(service.getClass().getSimpleName());
        first = false;
      }

      String logMessage = t.getName() + " with ID " + t.getId() +
        " has " + currentServicesInThread.size() +
        " services: " + reusableStringBuilder.toString();
      logs.put(t.getId(), logMessage);
      totalLogUpdates++; // Increment counter for log updates
    }
  }

  /**
   * Retrieves a service instance by its class name.
   * This method allows external components or other services to get a direct reference
   * to a registered service if its name is known.
   *
   * @param serviceName The simple class name of the service to retrieve.
   * @return The `BaseService` instance if found, or `null` if no service with that name is registered.
   */
  public BaseService getService(String serviceName) {
    if (serviceName == null || serviceName.isEmpty()) {
      println("ServiceScheduler: getService() called with null or empty serviceName.");
      return null;
    }
    return allServicesByName.get(serviceName);
  }

  /**
   * Aggregates and returns service metrics from all ServiceThreads.
   * The metrics are collected from each ServiceThread's internal metrics map.
   * The key of the returned map is the simple class name of the service,
   * which assumes that service class names are unique across the application
   * for the purpose of this aggregated view (consistent with `allServicesByName`).
   *
   * @return A Map where the key is the service's simple class name (String)
   *         and the value is the corresponding {@link ServiceMetrics} object.
   */
  public Map<String, ServiceMetrics> getAllServiceMetrics() {
    Map<String, ServiceMetrics> aggregatedMetrics = new HashMap<String, ServiceMetrics>();
    for (ServiceThread t : this.threads) {
      // getServiceMetricsMap() in ServiceThread returns an unmodifiable copy
      Map<BaseService, ServiceMetrics> threadMetrics = t.getServiceMetricsMap();
      for (Map.Entry<BaseService, ServiceMetrics> entry : threadMetrics.entrySet()) {
        // Using simple class name as the key, assuming it's unique for reporting.
        // This aligns with how allServicesByName is keyed.
        aggregatedMetrics.put(entry.getKey().getClass().getSimpleName(), entry.getValue());
      }
    }
    return aggregatedMetrics;
  }

  /**
   * Sends a message to a target service's input queue.
   * @param targetServiceName The simple class name of the target service.
   * @param message The message to send.
   * @return true if the message was successfully enqueued, false otherwise.
   */
  public boolean sendMessageToService(String targetServiceName, BaseMessage message) {
    if (message == null) {
      println("ServiceScheduler: Attempted to send a null message. Aborted.");
      return false;
    }
    if (targetServiceName == null || targetServiceName.isEmpty()) {
      println("ServiceScheduler: Target service name is null or empty for message type " + message.messageType + ". Aborted.");
      return false;
    }

    BaseService targetService = getService(targetServiceName);
    if (targetService != null) {
      boolean enqueued = targetService.inputQueue.enqueue(message);
      if (enqueued) {
        //println("ServiceScheduler: Message " + message.messageType + " sent to " + targetServiceName); // Can be too verbose
        return true;
      } else {
        println("WARNING: Message queue full for service: " + targetServiceName + ". Message of type " + message.messageType + " was not enqueued.");
        return false;
      }
    } else {
      println("ServiceScheduler: Failed to send message " + message.messageType + " to " + targetServiceName + ". Service not found.");
      return false;
    }
  }
}
