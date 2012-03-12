package edu.stanford.smallgraphs;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.commons.collections.CollectionUtils;
import org.apache.commons.collections.Predicate;
import org.apache.commons.collections.Transformer;
import org.apache.hadoop.io.LongWritable;

import com.google.gson.annotations.SerializedName;

public class Matches extends JSONWritable {

	@SerializedName("v")
	public long vertexId;
	@SerializedName("w")
	public Map<Integer, Collection<PathWithMatches>> pathWithMatchesByWalk;

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
			Map<Integer, Collection<PathWithMatches>> pathWithMatchesByWalk) {
		this.vertexId = vertexId;
		this.pathWithMatchesByWalk = pathWithMatchesByWalk;
	}

	public Matches addPathWithMatchesArrived(int viaWalk, MatchPath path,
			Matches matches) {
		if (pathWithMatchesByWalk == null)
			pathWithMatchesByWalk = new HashMap<Integer, Collection<PathWithMatches>>();
		Collection<PathWithMatches> matchesForWalk = pathWithMatchesByWalk
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

	public Iterable<Matches> getAllConsistentMatches(int[][][] pathset,
			int... walkIndices) {
		return getAllConsistentMatches(this, pathset, walkIndices);
	}

	public static Iterable<Matches> getAllConsistentMatches(Matches mInput,
			int[][][] pathset, int... walkIndices) {
		// first check if matches have all the necessary walks
		for (int w : walkIndices) {
			Collection<PathWithMatches> pms = mInput.pathWithMatchesByWalk
					.get(w);
			if (pms == null || pms.size() == 0)
				return Collections.emptyList();
		}
		// then try to find consistent matches
		if (pathset != null && pathset.length > 1) {
			Collection<Matches> ms = Collections.singleton(mInput);
			// distribute outermost conjunctions to innermost disjunctions
			for (int[][] paths : pathset) {
				List<Matches> matchesRefinedSoFar = new ArrayList<Matches>();
				// start refining from each disjunctive matches refined by
				// previous paths
				for (Matches mRefinedSoFar : ms) {
					// pick matches at the end of first path
					for (Matches mTarget : getInitialMatchesForWalkIndices(
							mRefinedSoFar, paths[0])) {
						Matches m = mRefinedSoFar;
						// and try refining this matches with each walk path
						for (int[] wi : paths) {
							m = getCoincidingMatchesWith(mTarget, wi, 0, m);
							if (m == null)
								break;
						}
						// null means no coinciding matches for a walk path
						if (m != null)
							matchesRefinedSoFar.add(m);
					}
				}
				ms = matchesRefinedSoFar;
				if (ms.size() == 0)
					break;
			}
			return ms;
		} else
			return Collections.singleton(mInput);
	}

	private static Matches getCoincidingMatchesWith(final Matches m,
			int[] walkIndices, int offset, Matches cursor) {
		int w = walkIndices[offset];
		Collection<PathWithMatches> pms = cursor.pathWithMatchesByWalk.get(w);
		if (offset + 1 == walkIndices.length) {
			// TODO maybe we can defer collection creation if we check predicate
			// first, then create if necessary
			@SuppressWarnings("unchecked")
			Collection<PathWithMatches> pms2 = CollectionUtils.select(pms,
					new Predicate() {
						@Override
						public boolean evaluate(Object o) {
							return ((PathWithMatches) o).matches == m;
						}
					});
			if (pms2.size() == 0)
				return null;
			else if (pms2.size() != pms.size())
				return createSlightlyDifferentMatches(cursor, w, pms2);
			else
				return cursor;
		} else {
			// TODO can we defer list creation until we really need it?
			List<PathWithMatches> pms2 = new ArrayList<Matches.PathWithMatches>();
			boolean diff = false;
			for (PathWithMatches pm : pms) {
				Matches newMatches = getCoincidingMatchesWith(m, walkIndices,
						offset + 1, pm.matches);
				if (newMatches == null)
					diff = true;
				else if (newMatches == pm.matches)
					pms2.add(pm);
				else {
					pms2.add(new PathWithMatches(pm.path, newMatches));
					diff = true;
				}
			}
			if (pms2.size() == 0)
				return null;
			else if (diff)
				return createSlightlyDifferentMatches(cursor, w, pms2);
			else
				return cursor;
		}
	}

	private static Matches createSlightlyDifferentMatches(Matches m, int w,
			Collection<PathWithMatches> pms) {
		// TODO avoid copying the whole map, since we only need to differ by one
		// entry
		Map<Integer, Collection<PathWithMatches>> newPathWithMatchesByWalk = new HashMap<Integer, Collection<PathWithMatches>>(
				m.pathWithMatchesByWalk);
		newPathWithMatchesByWalk.put(w, pms);
		return new Matches(m.vertexId, newPathWithMatchesByWalk);
	}

	private static List<Matches> getInitialMatchesForWalkIndices(Matches root,
			int... walkIndices) {
		List<Matches> ms = new ArrayList<Matches>();
		getInitialMatchesForWalkIndices(root, walkIndices, 0, ms);
		return ms;
	}

	private static void getInitialMatchesForWalkIndices(Matches cursor,
			int[] walkIndices, int offset, List<Matches> allInitialMatches) {
		int w = walkIndices[offset];
		if (offset - 1 == walkIndices.length) {
			for (PathWithMatches pm : cursor.pathWithMatchesByWalk.get(w))
				getInitialMatchesForWalkIndices(pm.matches, walkIndices,
						offset + 1, allInitialMatches);
		} else {
			for (PathWithMatches pm : cursor.pathWithMatchesByWalk.get(w))
				allInitialMatches.add(pm.matches);
		}
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

		// Map fixedSizeMap = new HashMap(m2.pathWithMatchesByWalk);
		// fixedSizeMap.put(2, null);

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