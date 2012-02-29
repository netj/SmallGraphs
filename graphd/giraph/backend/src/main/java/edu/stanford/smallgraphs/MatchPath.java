package edu.stanford.smallgraphs;

import java.util.ArrayList;
import java.util.List;

import com.google.gson.annotations.SerializedName;

public class MatchPath extends JSONWritable {

	@SerializedName("")
	public List<PathElement> elements;

	public static class PathElement extends JSONWritable {

		public long id;

		public PropertyMap properties;

		public PathElement(long id, PropertyMap properties) {
			super();
			this.id = id;
			this.properties = properties;
		}

	}

	public MatchPath() {
		// TODO get hint for initial size from walk
		elements = new ArrayList<MatchPath.PathElement>();
	}

	public MatchPath augment(long id) {
		return augment(id, null);
	}

	public MatchPath augment(long id, PropertyMap properties) {
		elements.add(new PathElement(id, null));
		return this;
	}

}