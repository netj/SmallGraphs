package edu.stanford.smallgraphs;

import java.util.ArrayList;
import java.util.List;

import com.google.gson.annotations.SerializedName;

public class MatchPath extends JSONWritable {

	@SerializedName("")
	public final List<PathElement> elements;

	public static class PathElement extends JSONWritable {

		public long id;

		public PropertyMap properties;

		public PathElement(long id) {
			this.id = id;
		}

		public PathElement(long id, PropertyMap properties) {
			this.id = id;
			this.properties = properties;
		}

	}

	public MatchPath() {
		// TODO get hint for initial size from walk
		elements = new ArrayList<MatchPath.PathElement>();
	}

	public MatchPath(MatchPath prefix, PathElement last) {
		this();
		elements.addAll(prefix.elements);
		elements.add(last);
	}

	public MatchPath(MatchPath prefix, long id) {
		this(prefix, new PathElement(id));
	}

	public MatchPath(MatchPath prefix, long id, PropertyMap properties) {
		this(prefix, new PathElement(id, properties));
	}

	public MatchPath augment(long id) {
		return augment(id, null);
	}

	public MatchPath augment(long id, PropertyMap properties) {
		elements.add(new PathElement(id, null));
		return this;
	}

}