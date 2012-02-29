package edu.stanford.smallgraphs;

import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;

import org.json.JSONObject;

public class VertexMatchingState extends PropertyMap {

	private final Matches matches;

	public VertexMatchingState(Long vertexId, JSONObject properties) {
		super(properties);
		matches = new Matches(vertexId);
	}

	public Matches getMatches() {
		return matches;
	}

	@Override
	public void readFields(DataInput in) throws IOException {
		super.readFields(in);
		matches.readFields(in);
	}

	@Override
	public void write(DataOutput out) throws IOException {
		super.write(out);
		matches.write(out);
	}

}
