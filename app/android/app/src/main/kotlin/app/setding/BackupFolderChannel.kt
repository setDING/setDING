package app.setding

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.storage.StorageManager
import android.provider.DocumentsContract
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileNotFoundException
import java.util.concurrent.Executors

/**
 * The folder of the automatic backup (ADR-0054) through the Storage Access
 * Framework: a folder of any document provider (Nextcloud, OneDrive,
 * Dropbox, …) chosen with the system's folder picker, kept with a persisted
 * permission. The location is the tree URI.
 *
 * Errors: `permission` when the permission was lost, `unavailable` when the
 * folder cannot be reached, `failed` otherwise.
 */
class BackupFolderChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "app.setding/backup_folder")
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(result)
            "deviceName" -> result.success(deviceName())
            "describe" -> background(result) {
                describe(Uri.parse(call.argument<String>("location")!!))
            }
            "list" -> background(result) { list(tree(call)).keys.toList() }
            "write" -> background(result) {
                write(
                    tree(call),
                    call.argument<String>("name")!!,
                    call.argument<String>("part")!!,
                    call.argument<ByteArray>("bytes")!!,
                )
                null
            }
            "delete" -> background(result) {
                val tree = tree(call)
                list(tree)[call.argument<String>("name")!!]?.let {
                    DocumentsContract.deleteDocument(activity.contentResolver, it)
                }
                null
            }
            else -> result.notImplemented()
        }
    }

    private fun deviceName(): String =
        Settings.Global.getString(activity.contentResolver, "device_name")
            ?: android.os.Build.MODEL

    private fun pick(result: MethodChannel.Result) {
        pending?.success(null)
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
        )
        try {
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (e: Exception) {
            pending = null
            result.error("unavailable", e.message, null)
        }
    }

    /** From [MainActivity.onActivityResult]; true when it was the picker. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        try {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            result.success(mapOf("location" to uri.toString()) + describe(uri))
        } catch (e: Exception) {
            result.error("permission", e.message, null)
        }
        return true
    }

    private fun background(result: MethodChannel.Result, run: () -> Any?) {
        io.execute {
            try {
                val value = run()
                main.post { result.success(value) }
            } catch (e: FolderException) {
                main.post { result.error(e.code, e.message, null) }
            } catch (e: SecurityException) {
                main.post { result.error("permission", e.message, null) }
            } catch (e: FileNotFoundException) {
                main.post { result.error("unavailable", e.message, null) }
            } catch (e: Exception) {
                main.post { result.error("failed", e.message, null) }
            }
        }
    }

    private class FolderException(val code: String, message: String) : Exception(message)

    /** The tree URI of the call, with a persisted write permission. */
    private fun tree(call: MethodCall): Uri {
        val uri = Uri.parse(call.argument<String>("location")!!)
        val granted = activity.contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isWritePermission
        }
        if (!granted) throw FolderException("permission", "No permission for $uri")
        return uri
    }

    private fun folderDocument(tree: Uri): Uri =
        DocumentsContract.buildDocumentUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )

    private fun name(tree: Uri): String {
        activity.contentResolver.query(
            folderDocument(tree),
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { if (it.moveToFirst()) return it.getString(0) ?: "" }
        return tree.lastPathSegment ?: ""
    }

    /**
     * How the person sees the folder (#889): `place` the storage volume or
     * the app it is in, `name` its path on a storage volume or else its name
     * (the document providers of other apps do not tell the parent folders).
     */
    private fun describe(tree: Uri): Map<String, String?> {
        val id = DocumentsContract.getTreeDocumentId(tree)
        if (tree.authority == EXTERNAL_STORAGE) {
            // "primary:Documents/Backups", or "<volume uuid>:…" on an SD card.
            val path = id.substringAfter(':', "")
            return mapOf(
                "place" to volumeName(id.substringBefore(':')),
                "name" to path.ifEmpty { "/" },
            )
        }
        return mapOf("place" to providerName(tree.authority), "name" to name(tree))
    }

    /** The name of the storage volume [id] ("primary" or its UUID). */
    private fun volumeName(id: String): String? = try {
        val storage = activity.getSystemService(StorageManager::class.java)
        val volume = if (id == "primary") {
            storage?.primaryStorageVolume
        } else {
            storage?.storageVolumes?.firstOrNull { it.uuid.equals(id, ignoreCase = true) }
        }
        volume?.getDescription(activity)
    } catch (e: Exception) {
        null
    }

    /** The name of the app behind the document provider [authority]. */
    private fun providerName(authority: String?): String? = try {
        val pm = activity.packageManager
        authority?.let { pm.resolveContentProvider(it, 0) }?.loadLabel(pm)?.toString()
    } catch (e: Exception) {
        null
    }

    /** The files directly in the folder: name to document URI. */
    private fun list(tree: Uri): Map<String, Uri> {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )
        val files = mutableMapOf<String, Uri>()
        val cursor = activity.contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
            null,
            null,
            null,
        ) ?: throw FolderException("unavailable", "Cannot list $tree")
        cursor.use {
            while (it.moveToNext()) {
                if (it.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) continue
                val name = it.getString(1) ?: continue
                files[name] = DocumentsContract.buildDocumentUriUsingTree(tree, it.getString(0))
            }
        }
        return files
    }

    /**
     * Writes [bytes] as [part], then renames it to [name], replacing an
     * existing [name]. Providers that cannot rename get [name] written
     * directly.
     */
    private fun write(tree: Uri, name: String, part: String, bytes: ByteArray) {
        val resolver = activity.contentResolver
        val existing = list(tree)
        existing[part]?.let { DocumentsContract.deleteDocument(resolver, it) }
        val folder = folderDocument(tree)
        val temp = DocumentsContract.createDocument(
            resolver,
            folder,
            "application/octet-stream",
            part,
        ) ?: throw FolderException("unavailable", "Cannot create $part")
        resolver.openOutputStream(temp, "wt")?.use { it.write(bytes) }
            ?: throw FolderException("failed", "Cannot write $part")
        existing[name]?.let { DocumentsContract.deleteDocument(resolver, it) }
        val renamed = try {
            DocumentsContract.renameDocument(resolver, temp, name)
        } catch (e: UnsupportedOperationException) {
            null
        }
        if (renamed == null) {
            // No rename: write the file itself, then remove the temporary one.
            val target = DocumentsContract.createDocument(
                resolver,
                folder,
                "application/zip",
                name,
            ) ?: throw FolderException("failed", "Cannot create $name")
            resolver.openOutputStream(target, "wt")?.use { it.write(bytes) }
                ?: throw FolderException("failed", "Cannot write $name")
            DocumentsContract.deleteDocument(resolver, temp)
        }
    }

    companion object {
        private const val REQUEST_CODE = 5404
        private const val EXTERNAL_STORAGE = "com.android.externalstorage.documents"
    }
}
