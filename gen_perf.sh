#!/usr/bin/bash

git_dir=$PWD
git_exec="$git_dir/git"
linux_dir="/home/abhishek/github_repos/linux"
write_graph_command="commit-graph write --no-progress"
commands=("log --topo-order -10000" "log --topo-order -100 v5.4 v5.5" "log --topo-order -100 v4.8 v4.9" "merge-base v5.4 v5.5" "merge-base v4.8 v4.9")

# Python script to parse output of time and generate mean, standard deviation.
read_time () {
	$git_dir/read_time $1
	rm $1
}

measure_time () {
	# Write commit graph a few times to avoid cold start
	for i in {1..3}
	do
		$git_exec $write_graph_command
	done

	# Note: Writing commit graph takes the longest, around 7 minutes in total.
	# Remove if not needed.
	for i in {1..3}
	do
		{ time $git_exec $write_graph_command; } 2>> output_file
	done

	echo $write_graph_command

	read_time output_file

	for command in "${commands[@]}"
	do
		echo "$command"
		for i in {1..25}
		do
			{ time $git_exec $command; } 1> /dev/null 2>> output_file
		done

		read_time output_file
	done
}

measure_perf () {
	export GIT_TRACE2_PERF="$git_dir/$1"
	$git_exec $write_graph_command
	
	for command in "${commands[@]}"
	do
		$git_exec $command 1> /dev/null
	done
	unset GIT_TRACE2_PERF
}

cd $linux_dir

echo "## Master"

measure_time
measure_perf 'master.perf'

echo "## Corrected Commit Dates with Monotonically Increasing offset, Metadata Chunk"
export GIT_METADATA_CHUNK_ENABLED=1
export GIT_GENERATION_NUMBER_V5=1

measure_time
measure_perf 'gen_v5.perf'

unset GIT_METADATA_CHUNK_ENABLED
unset GIT_GENERATION_NUMBER_V5

echo "## Corrected Commit Dates, Dates into Generation Data Chunk"
export GIT_GENERATION_DATA_CHUNK_ENABLED=1
export GIT_GENERATION_NUMBER_V3=1

measure_time
measure_perf 'gen_v3.perf'

unset GIT_GENERATION_DATA_CHUNK_ENABLED
unset GIT_GENERATION_NUMBER_V3

cd $git_dir
