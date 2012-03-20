package edu.stanford.smallgraphs.giraph;

import java.io.IOException;
import java.util.List;

import org.apache.giraph.graph.BasicVertex;
import org.apache.giraph.graph.VertexWriter;
import org.apache.giraph.lib.TextVertexOutputFormat;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.RecordWriter;
import org.apache.hadoop.mapreduce.TaskAttemptContext;
import org.json.JSONArray;

/**
 * VertexOutputFormat that supports {@link BaseSmallGraphGiraphVertex}
 */
public class FinalMatchesOutputFormat extends
		TextVertexOutputFormat<LongWritable, VertexMatchingState, PropertyMap> {
	@Override
	public VertexWriter<LongWritable, VertexMatchingState, PropertyMap> createVertexWriter(
			TaskAttemptContext context) throws IOException,
			InterruptedException {
		RecordWriter<Text, Text> recordWriter = textOutputFormat
				.getRecordWriter(context);
		return new TextVertexWriter<LongWritable, VertexMatchingState, PropertyMap>(
				recordWriter) {
			@Override
			public void writeVertex(
					BasicVertex<LongWritable, VertexMatchingState, PropertyMap, ?> vertex)
					throws IOException, InterruptedException {
				// output matches
				List<Matches> finalMatches = vertex.getVertexValue()
						.getAllFinalMatches();
				if (finalMatches != null)
					for (Matches matches : finalMatches) {
						getRecordWriter().write(new Text(matches.toString()),
								null);
					}
			}
		};
	}
}