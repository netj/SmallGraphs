package edu.stanford.smallgraphs;

import info.aduna.io.ByteArrayUtil;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.PrintStream;
import java.util.List;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.GnuParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.openrdf.model.Resource;
import org.openrdf.model.Statement;
import org.openrdf.model.URI;
import org.openrdf.model.Value;
import org.openrdf.rio.RDFFormat;
import org.openrdf.rio.RDFHandlerException;
import org.openrdf.rio.RDFParseException;
import org.openrdf.rio.RDFParser;
import org.openrdf.rio.RDFWriter;
import org.openrdf.rio.Rio;
import org.openrdf.rio.helpers.RDFHandlerBase;

import com.sleepycat.je.Database;
import com.sleepycat.je.DatabaseConfig;
import com.sleepycat.je.DatabaseEntry;
import com.sleepycat.je.Environment;
import com.sleepycat.je.EnvironmentConfig;
import com.sleepycat.je.LockMode;
import com.sleepycat.je.OperationStatus;

public class RDFDictionaryCodec {

	private Database dictionaryUriToId;
	private Database dictionaryIdToUri;

	private long counter;

	public RDFDictionaryCodec(File dictDir) {
		EnvironmentConfig envConfig = new EnvironmentConfig();
		envConfig.setAllowCreate(true);
		Environment myDbEnvironment = new Environment(dictDir, envConfig);
		DatabaseConfig dbConfig = new DatabaseConfig();
		dbConfig.setAllowCreate(true);
		dbConfig.setDeferredWrite(true);
		dictionaryUriToId = myDbEnvironment.openDatabase(null, "uri2id",
				dbConfig);
		dictionaryIdToUri = myDbEnvironment.openDatabase(null, "id2uri",
				dbConfig);

		counter = lookupLong(dictionaryUriToId, "", 0);

	}

	protected void finalize() throws Throwable {
		dictionaryIdToUri.close();
		dictionaryUriToId.close();
	}

	private Long lookupLong(Database db, String key, long defaultValue) {
		Long value = lookupLong(db, key);
		if (value != null)
			return value;
		else
			return defaultValue;
	}

	private DatabaseEntry dbEntry = new DatabaseEntry();
	private DatabaseEntry dbEntry2 = new DatabaseEntry();
	private DatabaseEntry longDBEntry = new DatabaseEntry(new byte[8]);

	public Long encode(String uri) {
		return lookupLong(dictionaryUriToId, uri);
	}

	private Long register(String uriString) {
		Long id = counter++;
		putLong(dictionaryUriToId, uriString, id);
		putString(dictionaryIdToUri, id, uriString);
		return id;
	}

	public Long encodeOrRegister(String uri) {
		Long id = encode(uri);
		if (id == null)
			id = register(uri);
		return id;
	}

	public String decode(Long id) {
		return lookupString(dictionaryIdToUri, id);
	}

	private Long lookupLong(Database db, String key) {
		dbEntry.setData(key.getBytes());
		if (db.get(null, dbEntry, dbEntry2, LockMode.DEFAULT) == OperationStatus.SUCCESS)
			return ByteArrayUtil.getLong(dbEntry2.getData(), 0);
		else
			return null;
	}

	private void putLong(Database db, String key, long value) {
		dbEntry.setData(key.getBytes());
		ByteArrayUtil.putLong(value, longDBEntry.getData(), 0);
		db.put(null, dbEntry, longDBEntry);
	}

	public String lookupString(Database db, long key, String defaultValue) {
		String value = lookupString(db, key);
		if (value != null)
			return value;
		else
			return defaultValue;
	}

	public String lookupString(Database db, long key) {
		ByteArrayUtil.putLong(key, longDBEntry.getData(), 0);
		if (db.get(null, longDBEntry, dbEntry2, LockMode.DEFAULT) == OperationStatus.SUCCESS)
			return new String(dbEntry2.getData()/* FIXME , "UTF-8" */);
		else
			return null;
	}

	public void putString(Database db, long key, String value) {
		dbEntry.setData(value.getBytes(/* FIXME "UTF-8" */));
		ByteArrayUtil.putLong(key, longDBEntry.getData(), 0);
		db.put(null, longDBEntry, dbEntry);
	}

	@SuppressWarnings("serial")
	private class MutableStatement implements Statement {

		private class EncodedURI implements URI {

			private String s;

			public String stringValue() {
				return s;
			}

			void setId(long id) {
				this.s = ":" + Long.toString(id);
			}

			void setURI(String uri) {
				this.s = uri;
			}

			public String getNamespace() {
				return null;
			}

			public String getLocalName() {
				return stringValue();
			}

			@Override
			public String toString() {
				return stringValue();
			}
		}

		EncodedURI sEnc = new EncodedURI(), pEnc = new EncodedURI(),
				oEnc = new EncodedURI();
		Resource s;
		Value o;

		private Long encodeURI(URI uri) {
			return encodeOrRegister(uri.stringValue());
		}

		private void encodeSubject(Resource subject) {
			if (subject instanceof URI) {
				URI uri = (URI) subject;
				sEnc.setId(encodeURI(uri));
				s = sEnc;
			} else
				s = subject;
		}

		private void encodePredicate(URI uri) {
			pEnc.setId(encodeURI(uri));
		}

		private void encodeObject(Value value) {
			if (value instanceof URI) {
				URI uri = (URI) value;
				oEnc.setId(encodeURI(uri));
				o = oEnc;
			} else {
				o = value;
			}
		}

		private String decodeId(URI uri) {
			return decode(Long.valueOf(uri.getLocalName()));
		}

		private void decodeSubject(Resource subject) {
			if (subject instanceof URI) {
				URI uri = (URI) subject;
				sEnc.setURI(decodeId(uri));
				s = sEnc;
			} else
				s = subject;
		}

		private void decodePredicate(URI uri) {
			pEnc.setURI(decodeId(uri));
		}

		private void decodeObject(Value value) {
			if (value instanceof URI) {
				URI uri = (URI) value;
				oEnc.setURI(decodeId(uri));
				o = oEnc;
			} else {
				o = value;
			}
		}

		public Resource getSubject() {
			return s;
		}

		public URI getPredicate() {
			return pEnc;
		}

		public Value getObject() {
			return o;
		}

		public Resource getContext() {
			return null;
		}

	}

	public void encode(InputStream input, RDFFormat inputFormat,
			String baseURI, OutputStream output, RDFFormat outputFormat)
			throws RDFParseException, RDFHandlerException,
			FileNotFoundException, IOException {
		RDFParser rdfParser = Rio.createParser(inputFormat);
		final RDFWriter rdfWriter = Rio.createWriter(outputFormat, output);
		final MutableStatement mutableStmt = new MutableStatement();
		rdfParser.setRDFHandler(new RDFHandlerBase() {
			@Override
			public void handleStatement(Statement st)
					throws RDFHandlerException {
				// assign ID and write each statement
				mutableStmt.encodeSubject(st.getSubject());
				mutableStmt.encodePredicate(st.getPredicate());
				mutableStmt.encodeObject(st.getObject());
				rdfWriter.handleStatement(mutableStmt);
			}
		});
		rdfWriter.startRDF();
		rdfParser.parse(input, baseURI);
		rdfWriter.endRDF();
		dictionaryIdToUri.sync();
		dictionaryUriToId.sync();
	}

	public void decode(InputStream input, RDFFormat inputFormat,
			OutputStream output, RDFFormat outputFormat)
			throws RDFHandlerException, RDFParseException, IOException {
		RDFParser rdfParser = Rio.createParser(inputFormat);
		final RDFWriter rdfWriter = Rio.createWriter(outputFormat, output);
		final MutableStatement mutableStmt = new MutableStatement();
		rdfParser.setRDFHandler(new RDFHandlerBase() {
			@Override
			public void handleStatement(Statement st)
					throws RDFHandlerException {
				// decode ID and write each statement
				mutableStmt.decodeSubject(st.getSubject());
				mutableStmt.decodePredicate(st.getPredicate());
				mutableStmt.decodeObject(st.getObject());
				rdfWriter.handleStatement(mutableStmt);
			}
		});
		rdfWriter.startRDF();
		rdfParser.parse(input, "");
		rdfWriter.endRDF();
	}

	public static void main(String[] args) {
		// command line options
		Options options = new Options();
		options.addOption("d", true, "Path to the dictionary");
		options.addOption("o", true, "Path to output file");
		options.addOption("u", true, "Base URI");
		options.addOption("f", true,
				"FORMAT of the RDF files; encoded is always N-Triples");
		CommandLine parsedArgs;
		try {
			parsedArgs = new GnuParser().parse(options, args, false);
		} catch (ParseException e) {
			printUsage(options);
			System.exit(1);
			return;
		}

		// process arguments
		String dictPath = parsedArgs.getOptionValue("d", "rdfDict");
		String baseURI = parsedArgs.getOptionValue("u", "");
		String outputPath = parsedArgs.getOptionValue("o");
		String formatName = parsedArgs.getOptionValue("f",
				RDFFormat.NTRIPLES.getName());
		RDFFormat format = RDFFormat.valueOf(formatName);
		@SuppressWarnings("unchecked")
		List<String> arguments = parsedArgs.getArgList();
		String command = arguments.size() > 0 ? arguments.remove(0) : "";

		try {
			// prepare some stuffs
			OutputStream out = System.out;
			if (outputPath != null) {
				File outputFile = new File(outputPath);
				outputFile.createNewFile();
				out = new FileOutputStream(outputFile);
			}
			PrintStream printer = new PrintStream(out);
			File dictDir = new File(dictPath);
			dictDir.mkdirs();
			RDFDictionaryCodec codec = new RDFDictionaryCodec(dictDir);
			// and run given command
			if (command.equals("encode")) {
				for (String filename : arguments) {
					InputStream input = filename.equals("-") ? System.in
							: new FileInputStream(filename);
					codec.encode(input, format, baseURI, out,
							RDFFormat.NTRIPLES);
				}
			} else if (command.equals("decode")) {
				for (String filename : arguments)
					codec.decode(new FileInputStream(filename),
							RDFFormat.NTRIPLES, out, format);
			} else if (command.equals("encode-uri")) {
				for (String uri : arguments)
					printer.println(codec.encode(uri));
			} else if (command.equals("encode-register-uri")) {
				for (String uri : arguments)
					printer.println(codec.encodeOrRegister(uri));
			} else if (command.equals("decode-uri")) {
				for (String id : arguments)
					printer.println(codec.decode(Long.valueOf(id)));
			} else {
				printUsage(options);
			}
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	private static void printUsage(Options options) {
		HelpFormatter formatter = new HelpFormatter();
		formatter.printHelp("RDFDictionaryCodec [OPTIONS] COMMAND [ARG...]",
				options);
		System.out.println();
		System.out
				.println(" COMMAND is one from: encode, decode, encode-uri, encode-register-uri, decode-uri");
		System.out.println();
		System.out.println("FORMAT is one from:\n"
				+ RDFFormat.values().toString());
	}

}
