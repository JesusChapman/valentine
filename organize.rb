require 'xcodeproj'
require 'fileutils'

project_path = 'Valentine.xcodeproj'
project = Xcodeproj::Project.open(project_path)
main_group = project.main_group.groups.find { |g| g.name == 'Valentine' || g.path == 'Valentine' }

structure = {
  'App' => ['ValentineApp.swift', 'ContentView.swift'],
  'Models' => ['Track.swift', 'LyricsAppearanceSettings.swift'],
  'Services' => ['AudioEngine.swift', 'LRCLibService.swift', 'MutagenInstallerService.swift', 'LyricsWriter.swift'],
  'Modifiers' => ['GlassBackgroundModifier.swift'],
  'Views/Player' => ['PlayerView.swift', 'MiniPlayerView.swift', 'PlaybackControlsView.swift', 'VolumeControlView.swift', 'WaveformView.swift'],
  'Views/Lyrics' => ['LyricsView.swift', 'LyricsEditorView.swift', 'LyricsSearchView.swift', 'LyricsAppearanceView.swift'],
  'Views/Playlist' => ['PlaylistView.swift'],
  'Views/Settings' => ['AboutView.swift', 'MutagenInstallerView.swift']
}

files_to_move = main_group.files.select { |f| f.path && f.path.end_with?('.swift') }

structure.each do |folder_path, files|
  current_group = main_group
  current_physical_path = 'Valentine'
  
  folder_path.split('/').each do |subfolder|
    current_physical_path = File.join(current_physical_path, subfolder)
    FileUtils.mkdir_p(current_physical_path)
    
    existing_group = current_group.groups.find { |g| g.name == subfolder || g.path == subfolder }
    current_group = existing_group || current_group.new_group(subfolder, subfolder)
  end
  
  files.each do |filename|
    file_ref = files_to_move.find { |f| f.path == filename || f.name == filename }
    if file_ref
      old_path = File.join('Valentine', file_ref.path)
      new_path = File.join(current_physical_path, filename)
      
      if File.exist?(old_path)
        FileUtils.mv(old_path, new_path)
        puts "Moved #{filename} to #{new_path}"
      end
      
      # Move the reference in the project
      file_ref.parent.children.delete(file_ref)
      current_group.children << file_ref
      file_ref.set_path(filename)
    end
  end
end

project.save
puts "Successfully organized!"
