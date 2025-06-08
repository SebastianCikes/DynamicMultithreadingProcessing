/**
 * A simple synchronized key-value store for basic inter-thread or inter-service data sharing.
 * `DataBus` provides a thread-safe way to put and get string data using a `HashMap`.
 * All access methods (`put` and `get`) are synchronized to prevent concurrent modification issues.
 *
 * While functional for simple use cases, consider the following:
 * - **Performance:** Heavy contention on this global DataBus could become a bottleneck.
 * - **Data Types:** Only supports String values. For complex data, serialization/deserialization
 *   would be needed, or a more advanced data sharing mechanism.
 * - **Granularity:** Synchronization is on the entire map, which can be coarse-grained.
 * - **Alternatives:** For more complex scenarios, consider using message passing between services
 *   (via `ServiceScheduler.sendMessageToService`) or more specialized concurrent data structures
 *   (e.g., from `java.util.concurrent`) if specific needs arise.
 *
 * This DataBus is primarily intended for simple, infrequent data sharing where the overhead
 * of message passing might be considered too high or where a global point of access for
 * certain shared values is convenient.
 */
class DataBus {
  // data: The internal HashMap storing the key-value pairs.
  // Access to this map is controlled by synchronized methods.
  private final HashMap<String, String> data = new HashMap<String, String>();

  /**
   * Stores a key-value pair in the DataBus.
   * This method is synchronized to ensure thread safety.
   * If the key already exists, its value will be overwritten.
   *
   * @param key The String key to associate with the value. Cannot be null.
   * @param value The String value to be stored. Can be null (though HashMap allows null values).
   */
  public synchronized void put(String key, String value) {
    // `HashMap.put` itself is not thread-safe if multiple threads call it concurrently.
    // The `synchronized` keyword on this method ensures that only one thread can execute
    // this block of code at a time for this `DataBus` instance.
    data.put(key, value);
  }

  /**
   * Retrieves a value associated with the given key from the DataBus.
   * This method is synchronized to ensure thread safety during read operations,
   * especially important if `put` operations can occur concurrently.
   *
   * @param key The String key whose associated value is to be returned. Cannot be null.
   * @return The String value associated with the key, or an empty string ("") if the key
   *         is not found. Using `getOrDefault` avoids returning null for missing keys,
   *         providing a default empty string instead.
   */
  public synchronized String get(String key) {
    // `HashMap.getOrDefault` is used to provide a default value if the key is not found,
    // preventing null pointer exceptions if the caller doesn't check for null.
    // The `synchronized` keyword ensures read operations are consistent with writes.
    return data.getOrDefault(key, "");
  }
}
