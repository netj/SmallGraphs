package edu.stanford.smallgraphs;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.commons.collections.CollectionUtils;
import org.apache.commons.collections.Transformer;
import org.apache.hadoop.io.LongWritable;

import com.google.gson.annotations.SerializedName;

public class Matches extends JSONWritable {

	@SerializedName("v")
	public long vertexId;
	@SerializedName("w")
	public Map<Integer, List<PathWithMatches>> pathWithMatchesByWalk;

	public static class PathWithMatches extends JSONWritable {
		public MatchPath path;
		public Matches matches;

		public PathWithMatches(MatchPath path, Matches matches) {
			super();
			this.path = path;
			this.matches = matches;
		}
	}

	public Matches(long atVertexId) {
		this(atVertexId, null);
	}

	public Matches(long vertexId,
			Map<Integer, List<PathWithMatches>> pathWithMatchesByWalk) {
		this.vertexId = vertexId;
		this.pathWithMatchesByWalk = pathWithMatchesByWalk;
	}

	public Matches addPathWithMatchesArrived(int viaWalk, MatchPath path,
			Matches matches) {
		if (pathWithMatchesByWalk == null)
			pathWithMatchesByWalk = new HashMap<Integer, List<PathWithMatches>>();
		List<PathWithMatches> matchesForWalk = pathWithMatchesByWalk
				.get(viaWalk);
		if (matchesForWalk == null) {
			matchesForWalk = new ArrayList<PathWithMatches>();
			pathWithMatchesByWalk.put(viaWalk, matchesForWalk);
		}
		matchesForWalk.add(new PathWithMatches(path, matches));
		return this;
	}

	public Matches addMatchesReturned(int returnedFromWalk, Matches matches) {
		return addPathWithMatchesArrived(returnedFromWalk, null, matches);
	}

	@SuppressWarnings("unchecked")
	public Iterable<LongWritable> getVertexIdsOfMatchesForWalk(int walk) {
		return CollectionUtils.collect(pathWithMatchesByWalk.get(walk),
				new Transformer() {
					@Override
					public Object transform(Object o) {
						return ((PathWithMatches) o).matches.vertexId;
					}
				});
	}

	public Iterable<Matches> getAllConsistentMatches(Matches m, int... walks) {
		// TODO Auto-generated method stub
		return null;
	}

	/**
	 * test for Writable and Gson
	 */
	public static void main(String[] args) throws IOException {
		Matches m1 = new Matches(1);
		MatchPath p1 = new MatchPath();
		p1.augment(101L).augment(9L).augment(103L);

		Matches m3a = new Matches(3);
		MatchPath p3a = new MatchPath();
		p3a.augment(201L);

		Matches m3b = new Matches(33);
		MatchPath p3b = new MatchPath();
		p3b.augment(301L).augment(8L).augment(303L).augment(7L).augment(305L);

		Matches m2 = new Matches(2);
		m2.addPathWithMatchesArrived(1, p1, m1)
				.addPathWithMatchesArrived(2, p3a, m3a)
				.addPathWithMatchesArrived(2, p3b, m3b);

		// write
		ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
		DataOutputStream os = new DataOutputStream(byteArrayOutputStream);
		m2.write(os);
		System.out.println(byteArrayOutputStream.toString());

		// read
		Matches m2readwrite = new Matches(0);
		ByteArrayInputStream byteArrayInputStream = new ByteArrayInputStream(
				byteArrayOutputStream.toByteArray());
		m2readwrite.readFields(new DataInputStream(byteArrayInputStream));

		// compare
		System.out.println(m2.equals(m2readwrite));
	}

}