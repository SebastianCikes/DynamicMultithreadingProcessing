import java.util.HashMap; // Already used, but good to ensure
import java.util.Map;     // For declaring allServicesByName as Map

class ServiceScheduler {
  // Di fatto non è uno scheduler ma imposta i servizi
  // a determinati thread
  
  private final Map<String, BaseService> allServicesByName = new HashMap<String, BaseService>();
  HashMap<Long, String> logs = new HashMap<Long, String>();
  ArrayList<ServiceThread> threads;
  int maxThreads;
  
  // Riusa StringBuilder per evitare allocazioni continue
  private StringBuilder reusableStringBuilder = new StringBuilder();
  
  // Contatori per debug
  private int totalServicesAdded = 0;
  private int totalLogUpdates = 0;
  
  ServiceScheduler(int maxThreads) {
    this.maxThreads = maxThreads;
    threads = new ArrayList<ServiceThread>();
    for (int i = 0; i < maxThreads; i++) {
      threads.add(new ServiceThread());
    }
  }
  
  void addService(BaseService s, int preferredThread) {
    ServiceThread target = null;
    String assignmentMethod = ""; // For logging how it was assigned

    // Attempt to assign to preferred thread
    if (preferredThread >= 0 && preferredThread < threads.size()) {
      target = threads.get(preferredThread);
      assignmentMethod = "preferred thread " + preferredThread;
    } else {
      if (preferredThread != -1) { // It was not "no preference", but an invalid preference
        println("Warning: Preferred thread " + preferredThread + " for service " + s.getClass().getSimpleName() + " is invalid. Using load balancing.");
      }
      // Fallback to load balancing
      if (!threads.isEmpty()) {
        target = threads.get(0); // Start with the first thread as a candidate
        for (ServiceThread t : threads) {
          if (t.assignedServices.size() < target.assignedServices.size()) {
            target = t;
          }
        }
        // Ensure threads.indexOf(target) is correct if threads can be reordered or not dense.
        // For ArrayList, indexOf works fine.
        assignmentMethod = "load balancing to thread index " + threads.indexOf(target);
      } else {
        println("Error: No available threads to assign service " + s.getClass().getSimpleName() + ". Service not added.");
        return; // Cannot assign service
      }
    }

    if (target != null) {
      target.addService(s);
      allServicesByName.put(s.getClass().getSimpleName(), s); // Store service by class name
      totalServicesAdded++;
      println("Service " + s.getClass().getSimpleName() + " assigned via " + assignmentMethod + " to " + target.getName() + " (ID: " + target.getId() + ")");

      // Update logs for the target thread
      reusableStringBuilder.setLength(0);
      for (int i = 0; i < target.assignedServices.size(); i++) {
        if (i > 0) {
          reusableStringBuilder.append(", ");
        }
        reusableStringBuilder.append(target.assignedServices.get(i).getClass().getSimpleName());
      }
      String logMessage = target.getName() + " with ID " + target.getId() +
                         " now has " + target.assignedServices.size() +
                         " services: " + reusableStringBuilder.toString();
      logs.put(target.getId(), logMessage);
      totalLogUpdates++;
    }
  }
  
  HashMap<Long, String> getLogs() {
    return logs;
  }
  
  void startAll() {
    for (ServiceThread t : threads) t.start();
  }
  
  // Metodi per debug memoria
  void printMemoryStats() {
    int totalActiveServices = 0;
    for (ServiceThread t : threads) {
      totalActiveServices += t.assignedServices.size();
    }
    
    println("=== ServiceScheduler Stats ===");
    println("Services added: " + totalServicesAdded);
    println("Active services: " + totalActiveServices);
    println("Log updates: " + totalLogUpdates);
    println("Active logs: " + logs.size());
    println("Threads: " + threads.size());
    
    // Possibile memory leak se totalServicesAdded >> totalActiveServices
    if (totalServicesAdded > totalActiveServices * 2) {
      println("WARNING: Molti servizi creati ma pochi attivi - possibile leak!");
    }
  }
  
  // Metodo per pulire servizi completati (se necessario)
  void cleanupCompletedServices() {
    for (ServiceThread t : threads) {
      // Rimuovi servizi che hanno finito il loro lavoro
      /*
      // Aggiungere logica per i singoli servizi e poi rimuoverli.
      // Dato che i servizi devono rimanere sempre attivi e
      // se ci sono delle modifiche, tipo eliminare una connessione TCP,
      // bisogna comunque arrestare il programma e eliminare la configurazione
      
      t.assignedServices.removeIf(service -> service.isCompleted());
      */
    }
    
    // Aggiorna i log dopo la pulizia
    updateAllLogs();
  }
  
  private void updateAllLogs() {
    for (ServiceThread t : threads) {
      if (t.assignedServices.size() == 0) {
        logs.remove(t.getId());
      } else {
        // Rigenera log per questo thread
        reusableStringBuilder.setLength(0);
        for (int i = 0; i < t.assignedServices.size(); i++) {
          if (i > 0) reusableStringBuilder.append(", ");
          reusableStringBuilder.append(t.assignedServices.get(i).getClass().getSimpleName());
        }
        
        String logMessage = t.getName() + " with ID " + t.getId() + 
                           " has " + t.assignedServices.size() + 
                           " services: " + reusableStringBuilder.toString();
        logs.put(t.getId(), logMessage);
      }
    }
  }

  /**
   * Retrieves a service instance by its class name.
   * @param serviceName The simple class name of the service.
   * @return The service instance, or null if not found.
   */
  public BaseService getService(String serviceName) {
    return allServicesByName.get(serviceName);
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
      targetService.inputQueue.enqueue(message);
      //println("ServiceScheduler: Message " + message.messageType + " sent to " + targetServiceName); // Can be too verbose
      return true;
    } else {
      println("ServiceScheduler: Failed to send message " + message.messageType + " to " + targetServiceName + ". Service not found.");
      return false;
    }
  }
}
