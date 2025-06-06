class DataBus {
  // Hash map per comunicazione tra thread
  
  HashMap<String, String> data = new HashMap<String, String>();

  synchronized void put(String key, String value) {
    data.put(key, value);
  }

  synchronized String get(String key) {
    return data.getOrDefault(key, "");
  }
}
