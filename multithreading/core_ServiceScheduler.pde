import java.util.ArrayList; // Required for ArrayList
import java.util.Collection; // Required for Collection
import java.util.HashMap;
import java.util.Map;

/**
 * Manages the lifecycle of services and distributes them across a pool of `ServiceThread` instances.
 * This class is central to the service-oriented architecture of the application. Its responsibilities include:
 * - Instantiating and configuring services, often based on external configuration (e.g., `config.json`).
 * - Assigning services to specific `ServiceThread`s for execution, with support for preferred thread assignment and basic load balancing.
 * - Starting all `ServiceThread`s, which in turn start their assigned services.
 * - Providing a mechanism for inter-service communication via `sendMessageToService`.
 * - Tracking all registered services for easy lookup via `getService`.
 * - Managing a logging system (`logs` map) to provide status information on `ServiceThread`s and their services.
 * - Periodically cleaning up services that have completed their tasks using `cleanupCompletedServices`.
 * - Offering methods to retrieve aggregated metrics from all services via `getAllServiceMetrics`.
 */
class ServiceScheduler {

  // allServicesByName: A map holding all registered services, keyed by their simple class name.
  // This allows for efficient global lookup of any service instance.
  // Note: Service class names should be unique across the application for this map to function correctly.
  private final Map<String, BaseService> allServicesByName = new HashMap<String, BaseService>();

  // logs: Stores human-readable log messages, typically keyed by the ID of the `ServiceThread`.
  // Each log message summarizes the services currently managed by that thread.
  // This is used by `DebugMonitor` or similar UI components to display system status.
  HashMap<Long, String> logs = new HashMap<Long, String>();

  // threads: A list of `ServiceThread` instances. Each `ServiceThread` is responsible for
  // executing one or more `BaseService` instances.
  ArrayList<ServiceThread> threads;
  // maxThreads: The maximum number of `ServiceThread` instances to create in the pool.
  // This typically corresponds to the number of available CPU cores or a configured value.
  int maxThreads;

  // reusableStringBuilder: A `StringBuilder` instance reused for constructing log messages.
  // This helps to reduce memory allocations and garbage collection overhead from frequent string concatenations.
  private StringBuilder reusableStringBuilder = new StringBuilder();

  // totalServicesAdded: A counter for the total number of services ever added to the scheduler.
  // Useful for debugging and monitoring the dynamic addition/removal of services.
  private int totalServicesAdded = 0;
  // totalLogUpdates: A counter for the number of times log messages have been updated.
  // Useful for debugging and monitoring logging activity.
  private int totalLogUpdates = 0;

  /**
   * Constructor for ServiceScheduler.
   * Initializes the pool of `ServiceThread` instances based on the `maxThreads` parameter.
   * Each `ServiceThread` is created but not yet started.
   *
   * @param maxThreads The number of `ServiceThread` instances to create and manage. This dictates
   *                   the level of concurrency for service execution.
   */
  ServiceScheduler(int maxThreads) {
    this.maxThreads = maxThreads;
    this.threads = new ArrayList<ServiceThread>();
    // Create the pool of ServiceThreads.
    for (int i = 0; i < maxThreads; i++) {
      // Each ServiceThread will run on its own system thread once startAll() is called.
      threads.add(new ServiceThread());
    }
  }

  /**
   * Adds a service to a `ServiceThread` for execution.
   * The method attempts to assign the service to a `preferredThread` if specified and valid.
   * If no valid preference is given, it uses a basic load balancing strategy, assigning the
   * service to the `ServiceThread` currently managing the fewest services.
   * Once assigned, the service is also registered in the `allServicesByName` map for global lookup.
   *
   * @param s The `BaseService` instance to add. Must not be null.
   * @param preferredThread The index of the preferred `ServiceThread` (0 to maxThreads-1).
   *                        Use -1 to indicate no preference, triggering load balancing.
   */
  void addService(BaseService s, int preferredThread) {
    if (s == null) {
      println("ServiceScheduler Error: Attempted to add a null service.");
      return;
    }

    ServiceThread targetThread = null;
    String assignmentMethod = ""; // For logging the assignment strategy.

    // Attempt to assign to the preferred thread if specified and valid.
    if (preferredThread >= 0 && preferredThread < threads.size()) {
      targetThread = threads.get(preferredThread);
      assignmentMethod = "preferred thread " + preferredThread;
    } else {
      // Log a warning if an invalid preference was given (but not for -1, which is intentional).
      if (preferredThread != -1) {
        println("ServiceScheduler Warning: Preferred thread " + preferredThread +
          " for service " + s.getClass().getSimpleName() + " is invalid. Using load balancing.");
      }
      // Fallback to load balancing: find the ServiceThread with the fewest services.
      if (!threads.isEmpty()) {
        targetThread = threads.get(0); // Start with the first thread as a candidate.
        int minServices = targetThread.getAssignedServices().size();

        for (ServiceThread t : threads) {
          if (t.getAssignedServices().size() < minServices) {
            minServices = t.getAssignedServices().size();
            targetThread = t;
          }
        }
        assignmentMethod = "load balancing to thread index " + threads.indexOf(targetThread);
      } else {
        // This case should ideally not be reached if maxThreads > 0.
        println("ServiceScheduler Error: No available ServiceThreads to assign service " +
          s.getClass().getSimpleName() + ". Service not added.");
        return;
      }
    }

    // If a target thread was successfully determined, add the service.
    if (targetThread != null) {
      targetThread.addService(s); // The ServiceThread handles its internal list.
      // Register the service globally by its class name.
      allServicesByName.put(s.getClass().getSimpleName(), s);
      totalServicesAdded++;
      println("ServiceScheduler: Service " + s.getClass().getSimpleName() +
        " assigned via " + assignmentMethod + " to " + targetThread.getName() +
        " (ID: " + targetThread.getId() + ")");
      updateLogForThread(targetThread); // Update the log summary for the affected thread.
    }
  }

  /**
   * Returns the current map of log messages.
   * Keys are typically `ServiceThread` IDs, and values are strings summarizing services on that thread.
   * This is intended for display or debugging purposes.
   *
   * @return A `HashMap<Long, String>` containing the log messages.
   */
  HashMap<Long, String> getLogs() {
    return logs;
  }

  /**
   * Starts all `ServiceThread` instances in the pool.
   * Each `ServiceThread`, upon starting, will begin its execution loop, which includes
   * calling `setup()` once for all its assigned services and then repeatedly calling their `loop()` methods.
   * If a `ServiceThread` is already alive (e.g., if `startAll` was called previously),
   * a warning is logged, as services added after a thread has started its main loop might not
   * be automatically picked up by the current `ServiceThread.run()` implementation.
   */
  void startAll() {
    for (ServiceThread t : threads) {
      if (!t.isAlive()) { // Only start the ServiceThread if it's not already running.
        t.start(); // This invokes the ServiceThread.run() method on a new system thread.
      } else {
        // This warning addresses the current ServiceThread design where services are primarily
        // processed if added before the thread's run() method fully initializes its loop.
        // Future enhancements could allow ServiceThreads to dynamically pick up services added later.
        println("ServiceScheduler Warning: ServiceThread " + t.getName() +
          " is already alive. Services added post-start might not run as expected " +
          "unless the ServiceThread's run() method is designed for dynamic service addition.");
      }
    }
  }

  /**
   * Prints various statistics about the ServiceScheduler and its managed services.
   * This includes counts of total services added, currently tracked services, services
   * actively managed in threads, log update counts, and the number of `ServiceThread` instances.
   * It also includes checks for potential discrepancies that might indicate issues.
   * Useful for debugging and monitoring the health of the service system.
   */
  void printMemoryStats() {
    int totalActiveServicesInThreads = 0;
    for (ServiceThread t : threads) {
      // getAssignedServices() returns a collection of services currently in that thread.
      totalActiveServicesInThreads += t.getAssignedServices().size();
    }

    println("=== ServiceScheduler Stats ===");
    println("Max Configured Threads: " + maxThreads);
    println("Actual ServiceThread Instances: " + threads.size());
    println("Total Services Ever Added (to scheduler): " + totalServicesAdded);
    println("Services Currently Tracked in allServicesByName (global map): " + allServicesByName.size());
    println("Services Actively Managed in All ServiceThreads: " + totalActiveServicesInThreads);
    println("Log Updates Counter: " + totalLogUpdates);
    println("Active Log Entries (for threads): " + logs.size());

    // Sanity check: Mismatch could indicate services added to allServicesByName but not to a thread,
    // or services removed from a thread but not from allServicesByName.
    if (allServicesByName.size() != totalActiveServicesInThreads) {
      println("ServiceScheduler WARNING: Mismatch between services in allServicesByName (" + allServicesByName.size() +
        ") and total services in threads (" + totalActiveServicesInThreads +
        "). This could indicate an issue with service registration or cleanup.");
    }
    // Heuristic: If many services were added but few are current, it suggests dynamic activity.
    if (totalServicesAdded > allServicesByName.size() * 1.5 && totalServicesAdded > 10) {
      println("ServiceScheduler INFO: Total services added ("+totalServicesAdded+") is significantly higher than " +
        "currently tracked ("+allServicesByName.size()+"). This indicates services are being " +
        "added and removed, which is normal for dynamic systems.");
    }
  }

  /**
   * Periodically called to identify and remove services that have completed their work.
   * A service is considered completed if its `isCompleted()` method returns `true`.
   * This method iterates through each {@link ServiceThread}, queries its managed services,
   * and requests the `ServiceThread` to remove any completed ones.
   *
   * Removal process for a completed service involves:
   * 1. The `ServiceThread` calls the service's `stop()` and `cleanup()` methods.
   * 2. The service is removed from the `ServiceThread`'s internal list.
   * 3. This method then removes the service from the scheduler's global `allServicesByName` map.
   *
   * Note: Service "crashes" (uncaught exceptions in `service.loop()`) are logged by `ServiceThread`
   * and may lead to the service being automatically stopped if `maxConsecutiveErrorsThreshold` is met.
   * Such stopped services would then be identified as "completed" by their `isCompleted()` method
   * (as `running` would be false) and cleaned up by this process.
   */
  void cleanupCompletedServices() {
    println("ServiceScheduler: Starting cleanup of completed services...");
    // Temporary list to hold services identified for removal from a single thread iteration.
    ArrayList<BaseService> servicesToRemoveFromCurrentThread;

    for (ServiceThread serviceThreadInstance : threads) {
      // Get a snapshot of services currently assigned to this thread.
      // Iterating over a copy or a stable collection is important if removal modifies the underlying list.
      // ServiceThread.getAssignedServices() already returns a copy.
      Collection<BaseService> assignedServices = serviceThreadInstance.getAssignedServices();

      if (assignedServices.isEmpty()) {
        continue; // Skip if this ServiceThread has no services.
      }

      servicesToRemoveFromCurrentThread = new ArrayList<BaseService>();

      // Identify services in this thread that are completed.
      for (BaseService service : assignedServices) {
        String serviceName = service.getClass().getSimpleName();
        if (service.isCompleted()) {
          println("ServiceScheduler: Service " + serviceName + " in " + serviceThreadInstance.getName() +
            " marked as completed. Scheduling for removal.");
          servicesToRemoveFromCurrentThread.add(service);
        }
      }

      // If any services were marked for removal from this thread:
      if (!servicesToRemoveFromCurrentThread.isEmpty()) {
        println("ServiceScheduler: Removing " + servicesToRemoveFromCurrentThread.size() +
          " service(s) from " + serviceThreadInstance.getName() + "...");
        for (BaseService serviceToRemove : servicesToRemoveFromCurrentThread) {
          String serviceName = serviceToRemove.getClass().getSimpleName();
          println("ServiceScheduler: Processing removal of " + serviceName +
            " from " + serviceThreadInstance.getName());

          // Step 1: Instruct the ServiceThread to remove the service.
          // This typically involves stopping its loop calls and calling its cleanup() method.
          serviceThreadInstance.removeService(serviceToRemove);

          // Step 2: Remove the service from the scheduler's global tracking map.
          BaseService removedFromGlobalMap = allServicesByName.remove(serviceName);
          if (removedFromGlobalMap != null) {
            println("ServiceScheduler: Service " + serviceName +
              " successfully removed from global tracking map.");
          } else {
            // This might happen if already removed in a previous cleanup phase or due to an error.
            println("ServiceScheduler Warning: Service " + serviceName +
              " was already removed or not found in global tracking map during this cleanup cycle.");
          }
        }
      }
    }

    println("ServiceScheduler: Cleanup finished. Updating all logs.");
    updateAllLogs(); // Refresh summary log messages after cleanup.
  }

  /**
   * Updates the log messages for all `ServiceThread`s.
   * This method iterates through each `ServiceThread` and calls `updateLogForThread`
   * to regenerate its summary log message based on the services it currently manages.
   * This is useful after changes like service addition or removal.
   */
  private void updateAllLogs() {
    for (ServiceThread t : threads) {
      updateLogForThread(t);
    }
  }

  /**
   * Updates the log message for a specific `ServiceThread`.
   * The log message typically includes the thread's name, ID, and a list of
   * simple class names of the services it currently manages.
   * Uses `reusableStringBuilder` to optimize string construction.
   *
   * @param t The `ServiceThread` whose log entry needs to be updated.
   */
  private void updateLogForThread(ServiceThread t) {
    // getAssignedServices() returns a Collection<BaseService>, which is a copy.
    Collection<BaseService> currentServicesInThread = t.getAssignedServices();

    if (currentServicesInThread.isEmpty()) {
      // If the thread has no services, remove its log entry.
      logs.remove(t.getId());
    } else {
      reusableStringBuilder.setLength(0); // Clear the StringBuilder for reuse.
      boolean firstService = true;
      for (BaseService service : currentServicesInThread) {
        if (!firstService) {
          reusableStringBuilder.append(", ");
        }
        reusableStringBuilder.append(service.getClass().getSimpleName());
        firstService = false;
      }

      String logMessage = t.getName() + " (ID: " + t.getId() + ") " + // Added ID for clarity
        "manages " + currentServicesInThread.size() +
        " services: [" + reusableStringBuilder.toString() + "]"; // Added brackets for clarity
      logs.put(t.getId(), logMessage);
      totalLogUpdates++; // Increment counter for monitoring log update frequency.
    }
  }

  /**
   * Retrieves a specific service instance by its simple class name.
   * This allows other parts of the application or other services to get a direct reference
   * to a registered service if its unique name is known.
   *
   * @param serviceName The simple class name of the service to retrieve (e.g., "ParserService").
   * @return The `BaseService` instance if found, or `null` if no service with that name is registered.
   */
  public BaseService getService(String serviceName) {
    if (serviceName == null || serviceName.isEmpty()) {
      println("ServiceScheduler Error: getService() called with null or empty serviceName.");
      return null;
    }
    return allServicesByName.get(serviceName);
  }

  /**
   * Aggregates and returns service metrics from all managed services across all `ServiceThread`s.
   * The metrics are collected from each `ServiceThread`'s internal metrics map.
   * The key of the returned map is the simple class name of the service. This assumes that
   * service class names are unique across the application for this aggregated view,
   * consistent with how services are stored in `allServicesByName`.
   *
   * @return A `Map` where the key is the service's simple class name (String)
   *         and the value is the corresponding {@link ServiceMetrics} object.
   *         Returns an empty map if no services or metrics are available.
   */
  public Map<String, ServiceMetrics> getAllServiceMetrics() {
    Map<String, ServiceMetrics> aggregatedMetrics = new HashMap<String, ServiceMetrics>();
    if (this.threads == null) return aggregatedMetrics; // Guard against null threads list

    for (ServiceThread t : this.threads) {
      // getServiceMetricsMap() in ServiceThread should return a copy or unmodifiable map.
      Map<BaseService, ServiceMetrics> threadMetrics = t.getServiceMetricsMap();
      if (threadMetrics != null) {
        for (Map.Entry<BaseService, ServiceMetrics> entry : threadMetrics.entrySet()) {
          // Using simple class name as the key, assuming it's unique for reporting.
          aggregatedMetrics.put(entry.getKey().getClass().getSimpleName(), entry.getValue());
        }
      }
    }
    return aggregatedMetrics;
  }

  /**
   * Sends a message to the input queue of a target service.
   * The target service is identified by its simple class name.
   * This is the primary method for inter-service communication.
   *
   * @param targetServiceName The simple class name of the service to receive the message.
   * @param message The `BaseMessage` instance to send. Must not be null.
   * @return `true` if the message was successfully looked up and enqueued to the target service's
   *         input queue. Returns `false` if the target service is not found, if the message is null,
   *         or if the target service's queue is full (and `enqueue` returns false).
   */
  public boolean sendMessageToService(String targetServiceName, BaseMessage message) {
    if (message == null) {
      println("ServiceScheduler Error: Attempted to send a null message.");
      return false;
    }
    if (targetServiceName == null || targetServiceName.isEmpty()) {
      println("ServiceScheduler Error: Target service name is null or empty for message type " +
        message.messageType + ". Message not sent.");
      return false;
    }

    BaseService targetService = getService(targetServiceName);
    if (targetService != null) {
      boolean enqueued = targetService.inputQueue.enqueue(message);
      if (enqueued) {
        // Verbose logging, uncomment if needed for debugging message flow.
        // println("ServiceScheduler: Message " + message.messageType + " successfully sent to " + targetServiceName);
        return true;
      } else {
        // This typically means the target service's input queue is full.
        println("ServiceScheduler WARNING: Message queue full for service: " + targetServiceName +
          ". Message of type " + message.messageType + " was not enqueued.");
        return false;
      }
    } else {
      println("ServiceScheduler Error: Failed to send message of type " + message.messageType +
        " to service " + targetServiceName + ". Service not found.");
      return false;
    }
  }
}
