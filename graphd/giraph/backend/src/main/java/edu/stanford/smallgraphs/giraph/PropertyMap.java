package edu.stanford.smallgraphs.giraph;

import java.util.Collection;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;

import org.json.JSONException;
import org.json.JSONObject;

import com.google.common.collect.Maps;
import com.google.gson.annotations.SerializedName;

public class PropertyMap extends JSONWritable implements Map<String, String> {

	@SerializedName("")
	Map<String, String> map;

	public PropertyMap() {
		map = Maps.newHashMap();
	}

	public PropertyMap(PropertyMap other) {
		if (other != null)
			map = Maps.newHashMap(other.map);
		else
			map = Maps.newHashMap();
	}

	PropertyMap(Map<String, String> other) {
		// TODO Auto-generated constructor stub
	}

	PropertyMap(JSONObject jsonObject) {
		this();
		@SuppressWarnings("unchecked")
		Iterator<String> keys = jsonObject.keys();
		while (keys.hasNext()) {
			try {
				String key = (String) keys.next();
				map.put(key, jsonObject.getString(key));
			} catch (JSONException e) {
			}
		}
	}

	JSONObject asJSONObject() {
		JSONObject jsonObject = new JSONObject();
		for (Map.Entry<String, String> entry : map.entrySet())
			try {
				jsonObject.put(entry.getKey(), entry.getValue());
			} catch (JSONException e) {
			}
		return jsonObject;
	}

	public Long getType() {
		String typeId = map.get("");
		return typeId != null ? Long.valueOf(typeId) : -1;
	}

	public PropertyMap project(String... keys) {
		PropertyMap projectedMap = new PropertyMap();
		for (String key : keys)
			projectedMap.put(key, map.get(key));
		return projectedMap;
	}

	public void clear() {
		map.clear();
	}

	public boolean containsKey(Object key) {
		return map.containsKey(key);
	}

	public boolean containsValue(Object value) {
		return map.containsValue(value);
	}

	public Set<java.util.Map.Entry<String, String>> entrySet() {
		return map.entrySet();
	}

	public boolean equals(Object o) {
		return map.equals(o);
	}

	public String get(Object key) {
		return map.get(key);
	}

	public int hashCode() {
		return map.hashCode();
	}

	public boolean isEmpty() {
		return map.isEmpty();
	}

	public Set<String> keySet() {
		return map.keySet();
	}

	public String put(String key, String value) {
		return map.put(key, value);
	}

	public void putAll(Map<? extends String, ? extends String> m) {
		map.putAll(m);
	}

	public String remove(Object key) {
		return map.remove(key);
	}

	public int size() {
		return map.size();
	}

	public Collection<String> values() {
		return map.values();
	}

}
