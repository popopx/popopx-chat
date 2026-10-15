package chat.popopx.common.views.badges

import androidx.compose.foundation.layout.*
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.icerock.moko.resources.compose.stringResource
import chat.popopx.common.platform.ColumnWithScrollBar
import chat.popopx.common.views.onboarding.ReadableTextWithLink
import chat.popopx.res.*

@Composable
fun BadgesHowItWorksView() {
  ColumnWithScrollBar(
    Modifier.padding(horizontal = 25.dp).padding(top = 8.dp),
    horizontalAlignment = Alignment.Start,
    verticalArrangement = Arrangement.spacedBy(12.dp)
  ) {
    Text(
      stringResource(MR.strings.badges_how_it_works_title),
      style = MaterialTheme.typography.h1,
      fontWeight = FontWeight.Bold,
      color = MaterialTheme.colors.primary,
      modifier = Modifier.padding(bottom = 16.dp)
    )
    Text(stringResource(MR.strings.badges_how_it_works_p1), style = MaterialTheme.typography.body1)
    Text(stringResource(MR.strings.badges_how_it_works_p2), style = MaterialTheme.typography.body1)
    Text(stringResource(MR.strings.badges_how_it_works_p3), style = MaterialTheme.typography.body1)
    ReadableTextWithLink(MR.strings.badges_how_it_works_read_more_with_link, "https://simplex.chat/blog/20260919-simplex-supporter-badges.html")
  }
}
