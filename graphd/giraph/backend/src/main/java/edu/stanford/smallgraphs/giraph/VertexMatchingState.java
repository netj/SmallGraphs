package edu.stanford.smallgraphs.giraph;

import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;
import java.util.List;

import org.apache.hadoop.io.LongWritable;

import com.google.common.collect.Lists;

public class VertexMatchingState extends PropertyMap {

	private Matches matches;
	private List<Matches> allFinalMatches = null;

	public VertexMatchingState() {
		this(null, null);
	}

	public VertexMatchingState(LongWritable vertexId, PropertyMap properties) {
		super(properties);
		this.matches = new Matches(vertexId);
	}

	public Matches getMatches() {
		return matches;
	}

	public List<Matches> getAllFinalMatches() {
		return allFinalMatches;
	}

	public void addFinalMatches(Matches m) {
		if (allFinalMatches == null)
			allFinalMatches = Lists.newArrayList();
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
			allFinalMatches = Lists.newArrayList();
			for (int i = 0; i < n; i++) {
				Matches m = new Matches();
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
