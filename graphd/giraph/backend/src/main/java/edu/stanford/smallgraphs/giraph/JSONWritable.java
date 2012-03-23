package edu.stanford.smallgraphs.giraph;

import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;
import java.lang.reflect.Field;
import java.util.Map;

import org.apache.commons.lang.builder.EqualsBuilder;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Writable;
import org.apache.hadoop.io.WritableUtils;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.TypeAdapter;
import com.google.gson.reflect.TypeToken;
import com.google.gson.stream.JsonReader;
import com.google.gson.stream.JsonToken;
import com.google.gson.stream.JsonWriter;

import edu.stanford.smallgraphs.giraph.Matches.PathElement;

public abstract class JSONWritable implements Writable {

	@Override
	public boolean equals(Object o) {
		return EqualsBuilder.reflectionEquals(this, o);
	}

	private static final Object typeAdapterForLongWritable = new TypeAdapter<LongWritable>() {
		@Override
		public void write(JsonWriter out, LongWritable value)
				throws IOException {
			if (value == null)
				out.nullValue();
			else
				out.value(value.get());
		}

		@Override
		public LongWritable read(JsonReader in) throws IOException {
			return new LongWritable(in.nextLong());
		}
	};

	private static final Object typeAdapterForPropertyMap = new TypeAdapter<PropertyMap>() {
		@Override
		public void write(JsonWriter out, PropertyMap value) throws IOException {
			if (value == null)
				out.nullValue();
			else
				defaultTypeAdapterForStringStringMap.write(out, value.map);
		}

		@Override
		public PropertyMap read(JsonReader in) throws IOException {
			if (in.peek().equals(JsonToken.NULL)) {
				in.nextNull();
				return null;
			} else
				return new PropertyMap(
						defaultTypeAdapterForStringStringMap.read(in));
		}
	};

	@SuppressWarnings("unused")
	private static final Object typeAdapterForPathElement = new TypeAdapter<PathElement>() {
		@Override
		public void write(JsonWriter out, PathElement value) throws IOException {
			if (value == null || value.id == null)
				out.nullValue();
			else
				defaultTypeAdapterForPathElement.write(out, value);
		}

		@Override
		public PathElement read(JsonReader in) throws IOException {
			if (in.peek().equals(JsonToken.NULL)) {
				in.nextNull();
				return new PathElement(null);
			} else
				return defaultTypeAdapterForPathElement.read(in);
		}
	};

	private static final Gson GSON = new GsonBuilder()
			// .setPrettyPrinting()
			.registerTypeAdapter(LongWritable.class, typeAdapterForLongWritable)
			.registerTypeAdapter(PropertyMap.class, typeAdapterForPropertyMap)
			// .registerTypeAdapter(PathElement.class,
			// typeAdapterForPathElement)
			.create();

	private static final TypeAdapter<Map<String, String>> defaultTypeAdapterForStringStringMap = GSON
			.getAdapter(new TypeToken<Map<String, String>>() {
			});
	private static final TypeAdapter<PathElement> defaultTypeAdapterForPathElement = GSON
			.getAdapter(PathElement.class);

	@Override
	public void readFields(DataInput in) throws IOException {
		// XXX this is very inefficient since Gson creates an extra copy of this
		// object :(
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
