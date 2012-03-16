package edu.stanford.smallgraphs;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;
import org.openrdf.model.Statement;
import org.openrdf.repository.Repository;
import org.openrdf.repository.RepositoryConnection;
import org.openrdf.repository.RepositoryException;
import org.openrdf.repository.sail.SailRepository;
import org.openrdf.rio.RDFFormat;
import org.openrdf.rio.RDFHandlerException;
import org.openrdf.rio.RDFParseException;
import org.openrdf.rio.RDFParser;
import org.openrdf.rio.Rio;
import org.openrdf.rio.helpers.RDFHandlerBase;
import org.openrdf.sail.memory.MemoryStore;

public class ImportGraphFromRDF {
/*
	public int run(String[] args) {
		try {
			if (args.length < 2) {
				System.err.println("Usage: import-rdf FILENAME BASEURI");
				return 1;
			}

			String fileName = args[0];
			String baseURI = args[1];
			// "http://example.org/example/local"; // FIXME
			String dataDirPath = ".";

			// use SAIL to load RDF graphs
			File dataDir = new File(dataDirPath, ".sail");
			MemoryStore memStore = new MemoryStore(dataDir);
			memStore.setSyncDelay(1000L);

			Repository myRepository = new SailRepository(memStore);
			myRepository.initialize();

			RepositoryConnection con = myRepository.getConnection();
			try {
				File file = new File(fileName);
				con.add(file, baseURI,
						RDFFormat.forFileName(fileName, RDFFormat.TURTLE));

				// TODO generate partition for giraph
			} catch (RDFParseException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
				return 2;
			} catch (IOException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
				return 2;
			} finally {
				con.close();
			}
		} catch (RepositoryException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
			return 2;
		}

		return 0;
	}

	private static class Map extends Mapper<Text, Text, Text, Text> {
		protected void map(
				Text key,
				Text value,
				org.apache.hadoop.mapreduce.Mapper<Text, Text, Text, Text>.Context context)
				throws IOException, InterruptedException {
context.get
		}
	}

	public static void main(String[] args) {
		System.exit(new ImportGraphFromRDF().run(args));
	}
*/
}
