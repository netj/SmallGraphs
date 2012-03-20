package edu.stanford.smallgraphs.giraph;

import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;
import java.lang.reflect.Field;

import org.apache.commons.lang.builder.EqualsBuilder;
import org.apache.hadoop.io.Writable;
import org.apache.hadoop.io.WritableUtils;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

public abstract class JSONWritable implements Writable {

	@Override
	public boolean equals(Object o) {
		return EqualsBuilder.reflectionEquals(this, o);
	}

	private static final Gson GSON = new GsonBuilder()
	// .setPrettyPrinting()
			.create();

	@Override
	public void readFields(DataInput in) throws IOException {
		// XXX this is very inefficient since Gson creates an extra copy of this object :(
		Object o = GSON.fromJson(WritableUtils.readString(in), this.getClass());
		for (Field field : this.getClass().getFields()) {
			try {
				field.set(this, field.get(o));
			} catch (IllegalArgumentException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			} catch (IllegalAccessException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}
	}

	@Override
	public void write(DataOutput out) throws IOException {
		WritableUtils.writeString(out, this.toString());
		// for (Field field : this.getClass().getFields()) {
		// try {
		// String value = GSON.toJson(field.get(this), field.getClass());
		// WritableUtils.writeString(out, value);
		// } catch (IllegalArgumentException e) {
		// // TODO Auto-generated catch block
		// e.printStackTrace();
		// } catch (IllegalAccessException e) {
		// // TODO Auto-generated catch block
		// e.printStackTrace();
		// }
		// }
	}

	@Override
	public String toString() {
		return GSON.toJson(this, this.getClass());
	}

}
