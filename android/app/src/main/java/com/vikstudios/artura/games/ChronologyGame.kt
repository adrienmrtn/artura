package com.vikstudios.artura.games

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.DragHandle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.vikstudios.artura.app.LocalContent
import com.vikstudios.artura.core.AType
import com.vikstudios.artura.core.ArtImage
import com.vikstudios.artura.core.CheckBadge
import com.vikstudios.artura.core.Haptics
import com.vikstudios.artura.core.L
import com.vikstudios.artura.core.Palette
import com.vikstudios.artura.core.PillButton
import com.vikstudios.artura.core.figtree
import kotlin.math.roundToInt

/** Timeline: put four artworks back in order, from oldest to newest (drag by the handle). */
@Composable
fun ChronologyGame(onFinish: (Int, Int) -> Unit) {
    val content = LocalContent.current
    var items by remember { mutableStateOf(content.artworks.shuffled().take(4)) }
    var checked by remember { mutableStateOf(false) }
    val sortedIDs = items.sortedBy { it.year }.map { it.id }
    val score = items.map { it.id }.zip(sortedIDs).count { it.first == it.second }

    // Reordering: the row being dragged, and how far it moved since its last swap.
    var dragging by remember { mutableStateOf<String?>(null) }
    var dragY by remember { mutableFloatStateOf(0f) }
    val step = with(LocalDensity.current) { (80 + 10).dp.toPx() }

    Column(Modifier.fillMaxSize().padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.padding(horizontal = 24.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(L("From oldest to newest"), style = AType.titleSmall, color = Palette.ink)
            Text(
                if (checked) (if (score == 1) L("1 artwork in the right spot.") else L("%@ artworks in the right spot.", "$score"))
                else L("Drag the artworks by the handle to put them in order."),
                style = AType.body, color = Palette.muted,
            )
        }

        Column(Modifier.padding(start = 24.dp, end = 16.dp, top = 5.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items.forEachIndexed { position, art ->
                val wellPlaced = sortedIDs.getOrNull(position) == art.id
                val isDragged = dragging == art.id
                val lift by animateDpAsState(if (isDragged) 8.dp else 0.dp, label = "lift")
                Row(
                    Modifier
                        .zIndex(if (isDragged) 1f else 0f)
                        .offset { IntOffset(0, if (isDragged) dragY.roundToInt() else 0) }
                        .shadow(lift, RoundedCornerShape(16.dp))
                        .fillMaxWidth()
                        .height(80.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(if (checked) (if (wellPlaced) Palette.greenSoft else Palette.redSoft) else Palette.card)
                        .padding(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    ArtImage(art.image, Modifier.size(64.dp).clip(RoundedCornerShape(12.dp)), small = true)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(art.title, style = figtree(15, FontWeight.SemiBold), color = Palette.ink, maxLines = 2)
                        Text(if (checked) "${art.artist} · ${art.yearLabel}" else art.artist, style = AType.caption, color = Palette.muted, maxLines = 1)
                    }
                    if (checked) {
                        if (wellPlaced) CheckBadge(Palette.green, 24.dp)
                        else Box(Modifier.size(24.dp).clip(CircleShape).background(Palette.red), contentAlignment = Alignment.Center) {
                            Icon(Icons.Rounded.Close, null, tint = Color.White, modifier = Modifier.size(15.dp))
                        }
                    } else {
                        Box(
                            Modifier.size(44.dp).pointerInput(art.id) {
                                detectDragGestures(
                                    onDragStart = { dragging = art.id; dragY = 0f; Haptics.selection() },
                                    onDragEnd = { dragging = null; dragY = 0f },
                                    onDragCancel = { dragging = null; dragY = 0f },
                                ) { change, amount ->
                                    change.consume()
                                    dragY += amount.y
                                    val list = items
                                    val from = list.indexOfFirst { it.id == art.id }
                                    if (dragY > step / 2 && from < list.size - 1) {
                                        items = list.toMutableList().also { it.add(from + 1, it.removeAt(from)) }
                                        dragY -= step
                                        Haptics.selection()
                                    } else if (dragY < -step / 2 && from > 0) {
                                        items = list.toMutableList().also { it.add(from - 1, it.removeAt(from)) }
                                        dragY += step
                                        Haptics.selection()
                                    }
                                }
                            },
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(Icons.Rounded.DragHandle, null, tint = Palette.muted, modifier = Modifier.size(24.dp))
                        }
                    }
                }
            }
        }

        Spacer(Modifier.weight(1f))

        PillButton(
            if (checked) L("See my score") else L("Check the order"),
            Modifier.padding(horizontal = 24.dp).padding(bottom = 16.dp),
        ) {
            if (checked) {
                onFinish(score, items.size)
            } else {
                checked = true
                if (score == items.size) Haptics.success() else Haptics.warning()
            }
        }
    }
}
