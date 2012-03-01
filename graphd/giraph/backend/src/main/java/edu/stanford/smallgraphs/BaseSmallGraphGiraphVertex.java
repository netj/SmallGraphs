/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package edu.stanford.smallgraphs;

import java.util.Iterator;

import org.apache.giraph.graph.EdgeListVertex;
import org.apache.giraph.graph.GiraphJob;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.util.Tool;
import org.apache.log4j.Logger;

import com.google.common.base.Preconditions;

/**
 * Base implementation of Giraph EdgeListVertex for SmallGraph query processing.
 */
public abstract class BaseSmallGraphGiraphVertex
		extends
		EdgeListVertex<LongWritable, VertexMatchingState, PropertyMap, MatchingMessage>
		implements Tool {

	/** Class logger */
	private static final Logger LOG = Logger
			.getLogger(BaseSmallGraphGiraphVertex.class);

	protected abstract void handleMessage(MatchingMessage msg);

	protected void rememberMatch(MatchPath path, Matches match, int forWalk) {
		getVertexValue().getMatches().addPathWithMatchesArrived(forWalk, path, match);
	}
	
	@Override
	public void compute(Iterator<MatchingMessage> msgIterator) {
		if (getSuperstep() == 0) {
			// Start message
			handleMessage(new MatchingMessage(0));
		}
		while (msgIterator.hasNext()) {
			handleMessage(msgIterator.next());
		}
		// if (LOG.isDebugEnabled()) {
		// LOG.debug("Vertex " + getVertexId() + " got minDist = " + minDist
		// + " vertex value = " + getVertexValue());
		// }
		// if (minDist < getVertexValue().get()) {
		// setVertexValue(new PropertiesWritable(minDist));
		// for (LongWritable targetVertexId : this) {
		// PropertiesWritable edgeValue = getEdgeValue(targetVertexId);
		// if (LOG.isDebugEnabled()) {
		// LOG.debug("Vertex " + getVertexId() + " sent to "
		// + targetVertexId + " = "
		// + (minDist + edgeValue.get()));
		// }
		// sendMsg(targetVertexId,
		// new PropertiesWritable(minDist + edgeValue.get()));
		// }
		// }
		voteToHalt();
	}

	@Override
	public int run(String[] args) throws Exception {
		Preconditions.checkArgument(args.length == 4,
				"run: Must have 4 arguments <input path> <output path> "
						+ "<source vertex id> <# of workers>");

		GiraphJob job = new GiraphJob(getConf(), getClass().getName());
		job.setVertexClass(getClass());
		job.setVertexInputFormatClass(PropertyGraphJSONVertexInputFormat.class);
		job.setVertexOutputFormatClass(PropertyGraphJSONVertexOutputFormat.class);
		FileInputFormat.addInputPath(job, new Path(args[0]));
		FileOutputFormat.setOutputPath(job, new Path(args[1]));
		// job.getConfiguration().setLong(BaseSmallGraphGiraphVertex.SOURCE_ID,
		// Long.parseLong(argArray[2]));
		// job.setWorkerConfiguration(Integer.parseInt(argArray[3]),
		// Integer.parseInt(argArray[3]), 100.0f);

		return job.run(true) ? 0 : -1;
	}

}
