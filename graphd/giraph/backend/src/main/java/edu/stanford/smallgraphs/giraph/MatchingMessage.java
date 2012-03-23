package edu.stanford.smallgraphs.giraph;

import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;
import java.lang.reflect.Field;
import java.util.List;

import org.apache.hadoop.io.Writable;

import edu.stanford.smallgraphs.giraph.Matches.PathElement;

public class MatchingMessage implements Writable {

	private int msgId;
	private final Matches matches;
	private final List<PathElement> path;

	public MatchingMessage(int msgId, Matches match, List<PathElement> path) {
		this.msgId = msgId;
		this.matches = match;
		this.path = path;
	}

	public MatchingMessage(int msgId, Matches match) {
		this(msgId, match, null);
	}

	public MatchingMessage(int msgId, List<PathElement> path) {
		this(msgId, null, path);
	}

	public MatchingMessage(int msgId) {
		this(msgId, null, null);
	}

	public int getMessageId() {
		return msgId;
	}

	public Matches getMatches() {
		return matches;
	}

	public List<PathElement> getPath() {
		return path;
	}

	@Override
	public void readFields(DataInput in) throws IOException {
		msgId = in.readInt();
		readMultipleOptional(in, MatchingMessage.class);
	}

	@Override
	public void write(DataOutput out) throws IOException {
		out.writeInt(msgId);
		writeMultipleOptional(out, MatchingMessage.class);
	}

	public void readMultipleOptional(DataInput in, Class<?> cls)
			throws IOException {
		int nonNullBitMap = in.readInt();
		int mask = 1;
		try {
			for (Field field : cls.getDeclaredFields()) {
				Class<?> fieldType = field.getType();
				if (Writable.class.isAssignableFrom(fieldType)) {
					if ((nonNullBitMap & mask) != 0) {
						Writable fieldObject = (Writable) field.get(this);
						if (fieldObject == null) {
							fieldObject = (Writable) fieldType.newInstance();
						}
						fieldObject.readFields(in);
					} else
						field.set(this, null);
					mask <<= 1;
					if (mask == 0) // when integer overflow'ed
						throw new IOException(
								"Too many declared fields. Supports no more than 32.");
				}
			}
		} catch (SecurityException e) {
			throw new IOException(e);
		} catch (IllegalArgumentException e) {
			throw new IOException(e);
		} catch (IllegalAccessException e) {
			throw new IOException(e);
		} catch (InstantiationException e) {
			throw new IOException(e);
		}
	}

	public void writeMultipleOptional(DataOutput out, Class<?> cls)
			throws IOException {
		int nonNullBitMap = 0;
		int flag = 1;
		try {
			for (Field field : cls.getDeclaredFields()) {
				Class<?> fieldType = field.getType();
				if (Writable.class.isAssignableFrom(fieldType)) {
					Writable fieldObject = (Writable) field.get(this);
					if (fieldObject != null)
						nonNullBitMap |= flag;
					flag <<= 1;
					if (flag == 0) // when integer overflow'ed
						throw new IOException(
								"Too many declared fields. Supports no more than 32.");
				}
			}
			out.writeInt(nonNullBitMap);
			for (Field field : cls.getDeclaredFields()) {
				Class<?> fieldType = field.getType();
				if (Writable.class.isAssignableFrom(fieldType)) {
					Writable fieldObject = (Writable) field.get(this);
					if (fieldObject != null)
						fieldObject.write(out);
				}
			}
		} catch (SecurityException e) {
			throw new IOException(e);
		} catch (IllegalArgumentException e) {
			throw new IOException(e);
		} catch (IllegalAccessException e) {
			throw new IOException(e);
		}
	}

}
