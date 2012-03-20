package edu.stanford.smallgraphs;

import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;
import java.util.Iterator;

import org.apache.hadoop.io.Writable;
import org.apache.hadoop.io.WritableUtils;
import org.json.JSONException;
import org.json.JSONObject;

public class PropertyMap implements Writable {

	private JSONObject properties;

	public PropertyMap() {
	}

	public PropertyMap(JSONObject properties) {
		this.properties = properties != null ? properties : new JSONObject();
	}

	public boolean equals(Object obj) {
		if (obj instanceof PropertyMap) {
			PropertyMap prop = (PropertyMap) obj;
			return properties.equals(prop.properties);
		}
		return false;
	}

	@SuppressWarnings("unchecked")
	public Iterator<String> keys() {
		return properties.keys();
	}

	public int size() {
		return properties.length();
	}

	public boolean getBoolean(String key, boolean defaultValue) {
		return properties.optBoolean(key, defaultValue);
	}

	public boolean getBoolean(String key) {
		return properties.optBoolean(key);
	}

	public double getDouble(String key, double defaultValue) {
		return properties.optDouble(key, defaultValue);
	}

	public double getDouble(String key) {
		return properties.optDouble(key);
	}

	public int getInt(String key, int defaultValue) {
		return properties.optInt(key, defaultValue);
	}

	public int getInt(String key) {
		return properties.optInt(key);
	}

	public long getLong(String key, long defaultValue) {
		return properties.optLong(key, defaultValue);
	}

	public long getLong(String key) {
		return properties.optLong(key);
	}

	public String getString(String key, String defaultValue) {
		return properties.optString(key, defaultValue);
	}

	public String getString(String key) {
		return properties.optString(key);
	}

	public PropertyMap put(String key, boolean value) throws JSONException {
		properties.put(key, value);
		return this;
	}

	public PropertyMap put(String key, double value) throws JSONException {
		properties.put(key, value);
		return this;
	}

	public PropertyMap put(String key, int value) throws JSONException {
		properties.put(key, value);
		return this;
	}

	public PropertyMap put(String key, long value) throws JSONException {
		properties.put(key, value);
		return this;
	}

	public Object remove(String key) {
		return properties.remove(key);
	}

	public String toString() {
		return properties.toString();
	}

	public JSONObject asJSONObject() {
		return properties;
	}

	@Override
	public void readFields(DataInput in) throws IOException {
		try {
			properties = new JSONObject(WritableUtils.readString(in));
		} catch (JSONException e) {
			throw new IOException(e);
		}
	}

	@Override
	public void write(DataOutput out) throws IOException {
		WritableUtils.writeString(out, properties.toString());
	}

	public long getType() {
		return getLong("", -1);
	}

}
