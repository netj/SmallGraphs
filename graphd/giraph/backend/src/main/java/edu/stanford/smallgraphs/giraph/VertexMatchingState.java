package edu.stanford.smallgraphs.giraph;

import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.json.JSONObject;

public class VertexMatchingState extends PropertyMap {

	private Matches matches;
	private List<Matches> allFinalMatches = null;

	public VertexMatchingState() {
		this(0L, null);
	}

	public VertexMatchingState(Long vertexId, JSONObject properties) {
		super(properties);
		matches = new Matches(vertexId);
	}

	public Matches getMatches() {
		return matches;
	}

	public List<Matches> getAllFinalMatches() {
		return allFinalMatches;
	}

	public void addFinalMatches(Matches m) {
		if (allFinalMatches == null)
			allFinalMatches = new ArrayList<Matches>();
		allFinalMatches.add(m);
	}

	@Override
	public void readFields(DataInput in) throws IOException {
		super.readFields(in);
		matches.readFields(in);
		int n = in.readInt();
		if (n == 0)
			allFinalMatches = null;
		else {
			allFinalMatches = new ArrayList<Matches>();
			for (int i = 0; i < n; i++) {
				Matches m = new Matches(0);
				m.readFields(in);
				allFinalMatches.add(m);
			}
		}
	}

	@Override
	public void write(DataOutput out) throws IOException {
		super.write(out);
		matches.write(out);
		if (allFinalMatches == null)
			out.writeInt(0);
		else {
			out.writeInt(allFinalMatches.size());
			for (Matches m : allFinalMatches)
				m.write(out);
		}
	}

}
