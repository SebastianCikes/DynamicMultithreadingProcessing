class ServiceThread extends Thread {
  // Crea thread
  
  ArrayList<BaseService> assignedServices = new ArrayList<BaseService>();

  void addService(BaseService s) {
    assignedServices.add(s);
  }

  public void run() {
    for (BaseService s : assignedServices) {
      Thread t = new Thread(s);  // Usa il Runnable di BaseService
      t.start();
    }
  }
}
