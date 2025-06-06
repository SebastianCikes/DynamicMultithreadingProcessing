class NotificationService extends BaseService {
  DataBus bus;
  NotificationService(DataBus bus) { this.bus = bus; }
  void setup() { println("NotificationService setup."); }
  void loop() { /* Notification logic */ }
}
